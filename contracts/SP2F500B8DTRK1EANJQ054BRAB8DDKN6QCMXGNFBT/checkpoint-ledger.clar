(define-map checkpoints principal uint)

(define-public (checkpoint)
  (begin (map-set checkpoints tx-sender burn-block-height) (ok true))
)
