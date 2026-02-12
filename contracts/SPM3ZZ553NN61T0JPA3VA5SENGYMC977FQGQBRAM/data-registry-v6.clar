(define-map data-store
  principal
  (string-utf8 256)
)

(define-public (set-data (data (string-utf8 256)))
  (begin
    (asserts! (> (len data) u0) (err u1))
    (map-set data-store tx-sender data)
    (ok true)
  )
)

(define-read-only (get-data (user principal))
  (ok (map-get? data-store user))
)
