(define-map reputation-scores principal uint)

(define-public (update-reputation (user principal) (score uint))
    (begin
        (map-set reputation-scores user score)
        (ok true)
    )
)

(define-read-only (get-reputation (user principal))
    (ok (default-to u0 (map-get? reputation-scores user)))
)
