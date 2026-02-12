(define-map permissions principal bool)

(define-public (enable)
  (begin (map-set permissions tx-sender true) (ok true))
)

(define-read-only (allowed (user principal))
  (is-some (map-get? permissions user))
)
