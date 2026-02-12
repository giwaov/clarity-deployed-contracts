(define-constant CONTRACT-VERSION u1)

(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-NO-FEES-AVAILABLE (err u401))
(define-constant ERR-INVALID-FEE-RATE (err u402))

(define-data-var contract-owner principal tx-sender)
(define-data-var performance-fee-bps uint u100)
(define-data-var accumulated-fees uint u0)
(define-data-var last-total-value uint u0)
(define-data-var total-fees-collected uint u0)

(define-public (calculate-performance-fee (current-value uint))
  (let
    (
      (previous-value (var-get last-total-value))
      (profit (if (> current-value previous-value)
                (- current-value previous-value)
                u0))
      (fee-amount (/ (* profit (var-get performance-fee-bps)) u10000))
    )
    (var-set last-total-value current-value)
    (var-set accumulated-fees (+ (var-get accumulated-fees) fee-amount))
    (ok fee-amount)
  )
)

(define-public (claim-fees (recipient principal))
  (let
    (
      (fees (var-get accumulated-fees))
    )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (> fees u0) ERR-NO-FEES-AVAILABLE)
    (var-set total-fees-collected (+ (var-get total-fees-collected) fees))
    (var-set accumulated-fees u0)
    (ok fees)
  )
)

(define-public (update-fee-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-rate u1000) ERR-INVALID-FEE-RATE)
    (var-set performance-fee-bps new-rate)
    (ok new-rate)
  )
)

(define-read-only (get-fee-info)
  (ok {
    performance-fee-bps: (var-get performance-fee-bps),
    accumulated-fees: (var-get accumulated-fees),
    total-fees-collected: (var-get total-fees-collected),
    last-total-value: (var-get last-total-value)
  })
)

(define-read-only (get-accumulated-fees)
  (ok (var-get accumulated-fees))
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok new-owner)
  )
)
