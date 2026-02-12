(define-map configs
  (string-ascii 50)
  (string-ascii 256)
)

(define-public (set-config
    (key (string-ascii 50))
    (value (string-ascii 256))
  )
  (begin
    (asserts! (> (len key) u0) (err u1))
    (asserts! (> (len value) u0) (err u2))
    (map-set configs key value)
    (ok true)
  )
)

(define-read-only (get-config (key (string-ascii 50)))
  (ok (map-get? configs key))
)
