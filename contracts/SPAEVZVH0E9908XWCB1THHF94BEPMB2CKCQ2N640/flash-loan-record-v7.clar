(define-map loan-records
  principal
  uint
)

(define-public (record-loan (amount uint))
  (begin
    (asserts! (> amount u0) (err u1))
    (map-set loan-records tx-sender amount)
    (ok true)
  )
)

(define-read-only (get-loan (user principal))
  (ok (map-get? loan-records user))
)
