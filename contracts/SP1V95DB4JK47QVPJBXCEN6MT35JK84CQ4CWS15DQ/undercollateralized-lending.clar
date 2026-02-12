(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-loan-defaulted (err u105))
(define-constant err-insufficient-credit (err u106))

(define-data-var loan-nonce uint u0)

(define-map credit-scores
  principal
  {
    base-score: uint,
    onchain-activity-score: uint,
    repayment-history-score: uint,
    total-borrowed: uint,
    total-repaid: uint,
    defaults: uint,
    credit-limit: uint
  }
)

(define-map undercollateralized-loans
  uint
  {
    borrower: principal,
    lender: principal,
    principal-amount: uint,
    interest-rate: uint,
    collateral-amount: uint,
    collateral-ratio: uint,
    outstanding-balance: uint,
    loan-start: uint,
    loan-end: uint,
    repaid: bool,
    defaulted: bool
  }
)

(define-map loan-repayments
  {loan-id: uint, payment-id: uint}
  {
    amount: uint,
    payment-block: uint
  }
)

(define-map borrower-loans principal (list 50 uint))
(define-map payment-count uint uint)

(define-public (initialize-credit-profile (base-score uint))
  (begin
    (asserts! (is-none (map-get? credit-scores tx-sender)) err-already-exists)
    (asserts! (<= base-score u1000) err-invalid-amount)
    (map-set credit-scores tx-sender
      {
        base-score: base-score,
        onchain-activity-score: u0,
        repayment-history-score: u0,
        total-borrowed: u0,
        total-repaid: u0,
        defaults: u0,
        credit-limit: (* base-score u1000)
      }
    )
    (ok true)
  )
)

(define-public (request-loan (lender principal) (amount uint) (collateral-amount uint) (interest-rate uint) (duration-blocks uint))
  (let
    (
      (credit (unwrap! (map-get? credit-scores tx-sender) err-not-found))
      (loan-id (+ (var-get loan-nonce) u1))
      (collateral-ratio (if (> amount u0) (/ (* collateral-amount u10000) amount) u0))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (<= amount (get credit-limit credit)) err-insufficient-credit)
    (asserts! (< collateral-ratio u10000) err-invalid-amount)
    (try! (stx-transfer? collateral-amount tx-sender (as-contract tx-sender)))
    (map-set undercollateralized-loans loan-id
      {
        borrower: tx-sender,
        lender: lender,
        principal-amount: amount,
        interest-rate: interest-rate,
        collateral-amount: collateral-amount,
        collateral-ratio: collateral-ratio,
        outstanding-balance: amount,
        loan-start: stacks-block-height,
        loan-end: (+ stacks-block-height duration-blocks),
        repaid: false,
        defaulted: false
      }
    )
    (map-set payment-count loan-id u0)
    (map-set borrower-loans tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? borrower-loans tx-sender)) loan-id) u50)))
    (map-set credit-scores tx-sender (merge credit {
      total-borrowed: (+ (get total-borrowed credit) amount)
    }))
    (var-set loan-nonce loan-id)
    (ok loan-id)
  )
)

(define-public (fund-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? undercollateralized-loans loan-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get lender loan)) err-unauthorized)
    (try! (stx-transfer? (get principal-amount loan) tx-sender (get borrower loan)))
    (ok true)
  )
)

(define-public (repay-loan (loan-id uint) (amount uint))
  (let
    (
      (loan (unwrap! (map-get? undercollateralized-loans loan-id) err-not-found))
      (credit (unwrap! (map-get? credit-scores tx-sender) err-not-found))
      (payment-id (+ (default-to u0 (map-get? payment-count loan-id)) u1))
      (new-balance (if (>= amount (get outstanding-balance loan)) u0 (- (get outstanding-balance loan) amount)))
    )
    (asserts! (is-eq tx-sender (get borrower loan)) err-unauthorized)
    (asserts! (not (get repaid loan)) err-already-exists)
    (asserts! (not (get defaulted loan)) err-loan-defaulted)
    (try! (stx-transfer? amount tx-sender (get lender loan)))
    (map-set loan-repayments {loan-id: loan-id, payment-id: payment-id}
      {
        amount: amount,
        payment-block: stacks-block-height
      }
    )
    (map-set payment-count loan-id payment-id)
    (map-set undercollateralized-loans loan-id (merge loan {
      outstanding-balance: new-balance,
      repaid: (is-eq new-balance u0)
    }))
    (if (is-eq new-balance u0)
      (begin
        (try! (as-contract (stx-transfer? (get collateral-amount loan) tx-sender (get borrower loan))))
        (map-set credit-scores tx-sender (merge credit {
          total-repaid: (+ (get total-repaid credit) (get principal-amount loan)),
          repayment-history-score: (+ (get repayment-history-score credit) u10),
          credit-limit: (+ (get credit-limit credit) u10000)
        }))
      )
      (map-set credit-scores tx-sender (merge credit {
        total-repaid: (+ (get total-repaid credit) amount)
      }))
    )
    (ok true)
  )
)

(define-public (mark-default (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? undercollateralized-loans loan-id) err-not-found))
      (credit (unwrap! (map-get? credit-scores (get borrower loan)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get lender loan)) err-unauthorized)
    (asserts! (> stacks-block-height (get loan-end loan)) err-not-found)
    (asserts! (> (get outstanding-balance loan) u0) err-invalid-amount)
    (try! (as-contract (stx-transfer? (get collateral-amount loan) tx-sender (get lender loan))))
    (map-set undercollateralized-loans loan-id (merge loan {defaulted: true}))
    (map-set credit-scores (get borrower loan) (merge credit {
      defaults: (+ (get defaults credit) u1),
      credit-limit: (/ (get credit-limit credit) u2)
    }))
    (ok true)
  )
)

(define-read-only (get-credit-score (user principal))
  (ok (map-get? credit-scores user))
)

(define-read-only (get-loan (loan-id uint))
  (ok (map-get? undercollateralized-loans loan-id))
)

(define-read-only (get-borrower-loans (borrower principal))
  (ok (map-get? borrower-loans borrower))
)

(define-read-only (get-repayment (loan-id uint) (payment-id uint))
  (ok (map-get? loan-repayments {loan-id: loan-id, payment-id: payment-id}))
)
