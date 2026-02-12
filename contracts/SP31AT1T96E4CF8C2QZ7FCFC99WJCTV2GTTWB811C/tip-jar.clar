(define-map tips principal uint)

(define-public (tip (amount uint))
    (begin
        ;; simplified non-custodial record
        (map-set tips tx-sender (+ (default-to u0 (map-get? tips tx-sender)) amount))
        (ok true)
    )
)
