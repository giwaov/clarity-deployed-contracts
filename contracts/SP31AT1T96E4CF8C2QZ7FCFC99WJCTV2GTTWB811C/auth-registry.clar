(define-map verified-users principal bool)

(define-public (add-user (user principal))
    (begin
        (map-set verified-users user true)
        (ok true)
    )
)

(define-read-only (is-verified (user principal))
    (ok (default-to false (map-get? verified-users user)))
)
