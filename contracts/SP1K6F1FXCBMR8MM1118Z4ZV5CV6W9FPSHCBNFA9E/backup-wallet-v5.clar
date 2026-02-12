(define-map backup-addresses
  principal
  principal
)

(define-public (set-backup (backup principal))
  (begin
    (asserts! (not (is-eq backup tx-sender)) (err u1))
    (map-set backup-addresses tx-sender backup)
    (ok true)
  )
)

(define-read-only (get-backup (owner principal))
  (ok (map-get? backup-addresses owner))
)
