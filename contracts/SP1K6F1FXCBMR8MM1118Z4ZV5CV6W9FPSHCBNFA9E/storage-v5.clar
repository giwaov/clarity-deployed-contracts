;; Simple Storage contract

(define-map store
  principal
  uint
)

(define-public (set-value (val uint))
  (begin
    (asserts! (> val u0) (err u1))
    (map-set store tx-sender val)
    (ok true)
  )
)

(define-read-only (get-value (user principal))
  (ok (default-to u0 (map-get? store user)))
)
