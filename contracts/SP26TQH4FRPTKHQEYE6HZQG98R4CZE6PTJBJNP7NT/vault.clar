(define-data-var balance uint u0)

(define-public (deposit (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set balance (+ (var-get balance) amount))
    (ok amount)
  )
)

(define-public (withdraw (amount uint))
  (begin
    (asserts! (>= (var-get balance) amount) (err u100))
    (try! (stx-transfer? amount (as-contract tx-sender) tx-sender))
    (var-set balance (- (var-get balance) amount))
    (ok amount)
  )
)
