(define-map status-records principal (string-ascii 50))

(define-public (set-status (status (string-ascii 50)))
    (begin
        (map-set status-records tx-sender status)
        (ok true)
    )
)

(define-read-only (get-status (user principal))
    (ok (map-get? status-records user))
)
