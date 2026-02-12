(define-map achievements
  principal
  uint
)

(define-public (award-badge
    (user principal)
    (level uint)
  )
  (begin
    (asserts! (not (is-eq user tx-sender)) (err u1))
    (asserts! (> level u0) (err u2))
    (map-set achievements user level)
    (ok true)
  )
)

(define-read-only (get-badge (user principal))
  (ok (default-to u0 (map-get? achievements user)))
)
