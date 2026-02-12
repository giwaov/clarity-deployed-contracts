(define-map tips principal uint)

(define-public (send-tip (amount uint))
    (let ((current-tips (default-to u0 (map-get? tips tx-sender))))
        (map-set tips tx-sender (+ current-tips amount))
        (ok true)
    )
)

(define-read-only (get-tips (user principal))
    (ok (default-to u0 (map-get? tips user)))
)
