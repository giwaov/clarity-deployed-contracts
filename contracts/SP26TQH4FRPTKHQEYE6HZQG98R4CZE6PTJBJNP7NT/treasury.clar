(define-constant OWNER tx-sender)

(define-public (withdraw (amount uint))
  (begin
    (asserts! (is-eq tx-sender OWNER) (err u401))
    (try! (stx-transfer? amount (as-contract tx-sender) OWNER))
    (ok amount)
  )
)
