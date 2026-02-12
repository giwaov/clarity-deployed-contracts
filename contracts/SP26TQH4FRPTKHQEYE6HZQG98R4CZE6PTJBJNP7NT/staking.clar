(define-map stakes principal uint)

(define-public (stake (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set stakes tx-sender (+ amount (default-to u0 (map-get? stakes tx-sender))))
    (ok amount)
  )
)
