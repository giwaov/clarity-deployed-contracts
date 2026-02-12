(define-map badges principal uint)

(define-public (set-badge (level uint))
  (begin
    (map-set badges tx-sender level)
    (ok level)
  )
)

(define-read-only (badge-of (user principal))
  (map-get? badges user)
)
