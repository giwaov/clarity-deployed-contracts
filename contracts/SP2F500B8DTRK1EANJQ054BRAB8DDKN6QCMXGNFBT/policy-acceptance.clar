(define-map accepted principal uint)

(define-public (accept)
  (begin (map-set accepted tx-sender burn-block-height) (ok true))
)
