(define-map backup principal principal)

(define-public (set-backup (backup-addr principal))
    (begin
        (map-set backup tx-sender backup-addr)
        (ok true)
    )
)

(define-read-only (get-backup (user principal))
    (ok (map-get? backup user))
)
