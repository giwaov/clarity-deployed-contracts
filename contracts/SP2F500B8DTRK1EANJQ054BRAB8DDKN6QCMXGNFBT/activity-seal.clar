(define-map seals principal uint)

(define-public (seal)
  (begin (map-set seals tx-sender burn-block-height) (ok true))
)
