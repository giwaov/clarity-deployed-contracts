(define-map backup-addresses principal principal)

(define-public (set-backup (backup principal))
    (begin
        (map-set backup-addresses tx-sender backup)
        (ok true)
    )
)

(define-read-only (get-backup (owner principal))
    (ok (map-get? backup-addresses owner))
)
