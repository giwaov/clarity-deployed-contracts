(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-invalid-warrant (err u117))

(define-data-var debt-nonce uint u0)

(define-map venture-debts
  uint
  {
    startup: principal,
    lender: principal,
    principal-amount: uint,
    interest-rate: uint,
    warrant-coverage: uint,
    equity-kicker: uint,
    runway-months: uint,
    outstanding: uint,
    disbursed: bool,
    active: bool,
    issue-block: uint,
    maturity-block: uint
  }
)

(define-map warrants
  {debt-id: uint, warrant-id: uint}
  {
    holder: principal,
    strike-price: uint,
    shares: uint,
    exercised: bool,
    issue-block: uint
  }
)

(define-map warrant-counter uint uint)
(define-map startup-debts principal (list 20 uint))
(define-map lender-debts principal (list 50 uint))

(define-public (issue-venture-debt (lender principal) (amount uint) (rate uint) (warrant-cov uint) 
                                    (equity-kick uint) (runway uint) (maturity uint))
  (let
    (
      (debt-id (+ (var-get debt-nonce) u1))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (asserts! (<= warrant-cov u30) err-invalid-warrant)
    (map-set venture-debts debt-id {
      startup: tx-sender,
      lender: lender,
      principal-amount: amount,
      interest-rate: rate,
      warrant-coverage: warrant-cov,
      equity-kicker: equity-kick,
      runway-months: runway,
      outstanding: amount,
      disbursed: false,
      active: false,
      issue-block: stacks-block-height,
      maturity-block: maturity
    })
    (map-set warrant-counter debt-id u0)
    (map-set startup-debts tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? startup-debts tx-sender)) debt-id) u20)))
    (map-set lender-debts lender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? lender-debts lender)) debt-id) u50)))
    (var-set debt-nonce debt-id)
    (ok debt-id)
  )
)

(define-public (disburse-funds (debt-id uint))
  (let
    (
      (debt (unwrap! (map-get? venture-debts debt-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get lender debt)) err-unauthorized)
    (asserts! (not (get disbursed debt)) err-invalid-amount)
    (try! (stx-transfer? (get principal-amount debt) tx-sender (get startup debt)))
    (map-set venture-debts debt-id (merge debt {disbursed: true, active: true}))
    (ok true)
  )
)

(define-public (issue-warrant (debt-id uint) (holder principal) (strike uint) (shares uint))
  (let
    (
      (debt (unwrap! (map-get? venture-debts debt-id) err-not-found))
      (warrant-id (+ (default-to u0 (map-get? warrant-counter debt-id)) u1))
    )
    (asserts! (is-eq tx-sender (get startup debt)) err-unauthorized)
    (map-set warrants {debt-id: debt-id, warrant-id: warrant-id} {
      holder: holder,
      strike-price: strike,
      shares: shares,
      exercised: false,
      issue-block: stacks-block-height
    })
    (map-set warrant-counter debt-id warrant-id)
    (ok warrant-id)
  )
)

(define-public (repay (debt-id uint) (amount uint))
  (let
    (
      (debt (unwrap! (map-get? venture-debts debt-id) err-not-found))
      (new-outstanding (if (>= amount (get outstanding debt)) u0 (- (get outstanding debt) amount)))
    )
    (asserts! (is-eq tx-sender (get startup debt)) err-unauthorized)
    (asserts! (get active debt) err-not-found)
    (try! (stx-transfer? amount tx-sender (get lender debt)))
    (map-set venture-debts debt-id (merge debt {
      outstanding: new-outstanding,
      active: (> new-outstanding u0)
    }))
    (ok true)
  )
)

(define-public (exercise-warrant (debt-id uint) (warrant-id uint) (payment uint))
  (let
    (
      (warrant (unwrap! (map-get? warrants {debt-id: debt-id, warrant-id: warrant-id}) err-not-found))
      (debt (unwrap! (map-get? venture-debts debt-id) err-not-found))
      (required (/ (* (get strike-price warrant) (get shares warrant)) u100))
    )
    (asserts! (is-eq tx-sender (get holder warrant)) err-unauthorized)
    (asserts! (not (get exercised warrant)) err-invalid-warrant)
    (asserts! (>= payment required) err-invalid-amount)
    (try! (stx-transfer? required tx-sender (get startup debt)))
    (map-set warrants {debt-id: debt-id, warrant-id: warrant-id} (merge warrant {exercised: true}))
    (ok true)
  )
)

(define-read-only (get-debt (debt-id uint))
  (ok (map-get? venture-debts debt-id))
)

(define-read-only (get-warrant (debt-id uint) (warrant-id uint))
  (ok (map-get? warrants {debt-id: debt-id, warrant-id: warrant-id}))
)

(define-read-only (get-startup-debts (startup principal))
  (ok (map-get? startup-debts startup))
)

(define-read-only (calculate-total-due (debt-id uint))
  (let
    (
      (debt (unwrap-panic (map-get? venture-debts debt-id)))
      (outstanding (get outstanding debt))
      (rate (get interest-rate debt))
      (elapsed (- stacks-block-height (get issue-block debt)))
    )
    (+ outstanding (/ (* outstanding (* rate elapsed)) u10000000))
  )
)

(define-read-only (get-warrant-value (debt-id uint) (warrant-id uint) (current-price uint))
  (let
    (
      (warrant (unwrap-panic (map-get? warrants {debt-id: debt-id, warrant-id: warrant-id})))
      (strike (get strike-price warrant))
      (shares (get shares warrant))
    )
    (if (> current-price strike)
      (ok (/ (* (- current-price strike) shares) u100))
      (ok u0)
    )
  )
)
