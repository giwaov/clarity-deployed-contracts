(define-map roles principal uint)

(define-public (set-role (role uint))
  (begin
    (map-set roles tx-sender role)
    (ok role)
  )
)
