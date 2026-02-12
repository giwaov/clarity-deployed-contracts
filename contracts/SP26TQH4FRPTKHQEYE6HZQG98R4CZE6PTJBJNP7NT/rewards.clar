(define-map rewards principal uint)

(define-public (claim (amount uint))
  (begin
    (map-set rewards tx-sender (+ amount (default-to u0 (map-get? rewards tx-sender))))
    (ok amount)
  )
)
