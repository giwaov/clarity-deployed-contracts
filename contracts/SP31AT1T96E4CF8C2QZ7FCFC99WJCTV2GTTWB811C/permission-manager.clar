(define-map authorized principal bool)
(define-constant contract-owner tx-sender)

(define-public (set-auth (user principal) (status bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) (err u403))
        (map-set authorized user status)
        (ok true)
    )
)

(define-read-only (is-authorized (user principal))
    (ok (default-to false (map-get? authorized user)))
)
