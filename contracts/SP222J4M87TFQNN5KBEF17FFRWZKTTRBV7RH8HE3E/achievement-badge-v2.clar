(define-map achievements principal uint)

(define-public (award-badge (user principal) (level uint))
    (begin
        (map-set achievements user level)
        (ok true)
    )
)

(define-read-only (get-badge (user principal))
    (ok (default-to u0 (map-get? achievements user)))
)
