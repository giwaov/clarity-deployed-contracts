(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-maturity-not-reached (err u105))
(define-constant err-already-repaid (err u106))
(define-constant err-insufficient-payment (err u107))
(define-constant err-defaulted (err u108))

(define-data-var debt-nonce uint u0)

(define-map debts
  uint
  {
    borrower: principal,
    lender: principal,
    principal-amount: uint,
    interest-rate: uint,
    outstanding-balance: uint,
    issue-block: uint,
    maturity-block: uint,
    repaid: bool,
    defaulted: bool
  }
)

(define-map payments
  {debt-id: uint, payment-id: uint}
  {
    amount: uint,
    block-height: uint,
    payment-type: (string-ascii 20)
  }
)

(define-map payment-count uint uint)

(define-map borrower-debts principal (list 100 uint))
(define-map lender-debts principal (list 100 uint))

(define-public (issue-debt (lender principal) (principal-amount uint) (interest-rate uint) (maturity-block uint))
  (let
    (
      (debt-id (+ (var-get debt-nonce) u1))
      (borrower tx-sender)
      (current-height stacks-block-height)
    )
    (asserts! (> principal-amount u0) err-invalid-amount)
    (asserts! (> maturity-block current-height) err-invalid-amount)
    (map-set debts debt-id
      {
        borrower: borrower,
        lender: lender,
        principal-amount: principal-amount,
        interest-rate: interest-rate,
        outstanding-balance: principal-amount,
        issue-block: current-height,
        maturity-block: maturity-block,
        repaid: false,
        defaulted: false
      }
    )
    (map-set payment-count debt-id u0)
    (map-set borrower-debts borrower 
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? borrower-debts borrower)) debt-id) u100)))
    (map-set lender-debts lender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? lender-debts lender)) debt-id) u100)))
    (var-set debt-nonce debt-id)
    (ok debt-id)
  )
)

(define-public (make-payment (debt-id uint) (amount uint))
  (let
    (
      (debt (unwrap! (map-get? debts debt-id) err-not-found))
      (borrower (get borrower debt))
      (current-balance (get outstanding-balance debt))
      (new-balance (if (>= amount current-balance) u0 (- current-balance amount)))
      (payment-id (+ (default-to u0 (map-get? payment-count debt-id)) u1))
    )
    (asserts! (is-eq tx-sender borrower) err-unauthorized)
    (asserts! (not (get repaid debt)) err-already-repaid)
    (asserts! (not (get defaulted debt)) err-defaulted)
    (asserts! (> amount u0) err-invalid-amount)
    (try! (stx-transfer? amount tx-sender (get lender debt)))
    (map-set payments {debt-id: debt-id, payment-id: payment-id}
      {
        amount: amount,
        block-height: stacks-block-height,
        payment-type: "payment"
      }
    )
    (map-set payment-count debt-id payment-id)
    (map-set debts debt-id (merge debt {
      outstanding-balance: new-balance,
      repaid: (is-eq new-balance u0)
    }))
    (ok true)
  )
)

(define-public (repay-full (debt-id uint))
  (let
    (
      (debt (unwrap! (map-get? debts debt-id) err-not-found))
      (borrower (get borrower debt))
      (total-due (calculate-total-due debt-id))
    )
    (asserts! (is-eq tx-sender borrower) err-unauthorized)
    (asserts! (not (get repaid debt)) err-already-repaid)
    (asserts! (not (get defaulted debt)) err-defaulted)
    (try! (stx-transfer? total-due tx-sender (get lender debt)))
    (let
      (
        (payment-id (+ (default-to u0 (map-get? payment-count debt-id)) u1))
      )
      (map-set payments {debt-id: debt-id, payment-id: payment-id}
        {
          amount: total-due,
          block-height: stacks-block-height,
          payment-type: "full-repayment"
        }
      )
      (map-set payment-count debt-id payment-id)
      (map-set debts debt-id (merge debt {
        outstanding-balance: u0,
        repaid: true
      }))
      (ok true)
    )
  )
)

(define-public (mark-default (debt-id uint))
  (let
    (
      (debt (unwrap! (map-get? debts debt-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get lender debt)) err-unauthorized)
    (asserts! (not (get repaid debt)) err-already-repaid)
    (asserts! (> stacks-block-height (get maturity-block debt)) err-maturity-not-reached)
    (asserts! (> (get outstanding-balance debt) u0) err-invalid-amount)
    (map-set debts debt-id (merge debt {defaulted: true}))
    (ok true)
  )
)

(define-read-only (get-debt (debt-id uint))
  (ok (map-get? debts debt-id))
)

(define-read-only (get-payment (debt-id uint) (payment-id uint))
  (ok (map-get? payments {debt-id: debt-id, payment-id: payment-id}))
)

(define-read-only (get-borrower-debts (borrower principal))
  (ok (map-get? borrower-debts borrower))
)

(define-read-only (get-lender-debts (lender principal))
  (ok (map-get? lender-debts lender))
)

(define-read-only (calculate-total-due (debt-id uint))
  (let
    (
      (debt (unwrap-panic (map-get? debts debt-id)))
      (principal (get outstanding-balance debt))
      (interest-rate (get interest-rate debt))
      (blocks-elapsed (- stacks-block-height (get issue-block debt)))
    )
    (+ principal (/ (* principal (* interest-rate blocks-elapsed)) u10000000))
  )
)

(define-read-only (get-debt-status (debt-id uint))
  (let
    (
      (debt (unwrap-panic (map-get? debts debt-id)))
    )
    (ok {
      repaid: (get repaid debt),
      defaulted: (get defaulted debt),
      overdue: (and (> stacks-block-height (get maturity-block debt)) (not (get repaid debt))),
      outstanding: (get outstanding-balance debt)
    })
  )
)
