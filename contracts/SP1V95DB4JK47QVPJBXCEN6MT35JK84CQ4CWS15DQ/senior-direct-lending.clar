(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-loan-active (err u109))
(define-constant err-insufficient-collateral (err u110))
(define-constant err-already-funded (err u111))

(define-data-var loan-nonce uint u0)

(define-map loans
  uint
  {
    borrower: principal,
    lender: principal,
    loan-amount: uint,
    interest-rate: uint,
    collateral-value: uint,
    ltv-ratio: uint,
    outstanding: uint,
    funded: bool,
    active: bool,
    start-block: uint,
    term-blocks: uint
  }
)

(define-map loan-payments
  {loan-id: uint, payment-id: uint}
  {amount: uint, block: uint, type: (string-ascii 20)}
)

(define-map payment-counter uint uint)
(define-map borrower-loans principal (list 50 uint))
(define-map lender-loans principal (list 50 uint))

(define-public (create-loan (lender principal) (amount uint) (rate uint) (collateral uint) (ltv uint) (term uint))
  (let
    (
      (loan-id (+ (var-get loan-nonce) u1))
      (borrower tx-sender)
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (>= collateral (/ (* amount u100) ltv)) err-insufficient-collateral)
    (map-set loans loan-id {
      borrower: borrower,
      lender: lender,
      loan-amount: amount,
      interest-rate: rate,
      collateral-value: collateral,
      ltv-ratio: ltv,
      outstanding: amount,
      funded: false,
      active: false,
      start-block: u0,
      term-blocks: term
    })
    (map-set payment-counter loan-id u0)
    (map-set borrower-loans borrower (unwrap-panic (as-max-len? (append (default-to (list) (map-get? borrower-loans borrower)) loan-id) u50)))
    (map-set lender-loans lender (unwrap-panic (as-max-len? (append (default-to (list) (map-get? lender-loans lender)) loan-id) u50)))
    (var-set loan-nonce loan-id)
    (ok loan-id)
  )
)

(define-public (fund-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get lender loan)) err-unauthorized)
    (asserts! (not (get funded loan)) err-already-funded)
    (try! (stx-transfer? (get loan-amount loan) tx-sender (get borrower loan)))
    (map-set loans loan-id (merge loan {funded: true, active: true, start-block: stacks-block-height}))
    (ok true)
  )
)

(define-public (make-repayment (loan-id uint) (amount uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) err-not-found))
      (new-outstanding (if (>= amount (get outstanding loan)) u0 (- (get outstanding loan) amount)))
      (pid (+ (default-to u0 (map-get? payment-counter loan-id)) u1))
    )
    (asserts! (is-eq tx-sender (get borrower loan)) err-unauthorized)
    (asserts! (get active loan) err-loan-active)
    (try! (stx-transfer? amount tx-sender (get lender loan)))
    (map-set loan-payments {loan-id: loan-id, payment-id: pid} {amount: amount, block: stacks-block-height, type: "repayment"})
    (map-set payment-counter loan-id pid)
    (map-set loans loan-id (merge loan {outstanding: new-outstanding, active: (> new-outstanding u0)}))
    (ok true)
  )
)

(define-public (close-loan (loan-id uint))
  (let
    (
      (loan (unwrap! (map-get? loans loan-id) err-not-found))
      (total (calculate-payoff loan-id))
    )
    (asserts! (is-eq tx-sender (get borrower loan)) err-unauthorized)
    (asserts! (get active loan) err-loan-active)
    (try! (stx-transfer? total tx-sender (get lender loan)))
    (map-set loans loan-id (merge loan {outstanding: u0, active: false}))
    (ok true)
  )
)

(define-read-only (get-loan (loan-id uint))
  (ok (map-get? loans loan-id))
)

(define-read-only (get-borrower-loans (borrower principal))
  (ok (map-get? borrower-loans borrower))
)

(define-read-only (get-lender-loans (lender principal))
  (ok (map-get? lender-loans lender))
)

(define-read-only (calculate-payoff (loan-id uint))
  (let
    (
      (loan (unwrap-panic (map-get? loans loan-id)))
      (outstanding (get outstanding loan))
      (rate (get interest-rate loan))
      (elapsed (- stacks-block-height (get start-block loan)))
    )
    (+ outstanding (/ (* outstanding (* rate elapsed)) u10000000))
  )
)

(define-read-only (get-loan-health (loan-id uint))
  (let
    (
      (loan (unwrap-panic (map-get? loans loan-id)))
    )
    (ok {
      funded: (get funded loan),
      active: (get active loan),
      outstanding: (get outstanding loan),
      ltv: (/ (* (get outstanding loan) u100) (get collateral-value loan))
    })
  )
)
