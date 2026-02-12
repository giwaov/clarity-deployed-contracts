(define-map status principal (string-ascii 10))

(define-public (set-status (s (string-ascii 10)))
    (begin
        (map-set status tx-sender s)
        (ok true)
    )
)

(define-read-only (get-status (who principal))
    (ok (map-get? status who))
)
