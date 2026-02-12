(define-map registry principal (buff 32))

(define-public (register (hash (buff 32)))
    (begin
        (map-set registry tx-sender hash)
        (ok true)
    )
)

(define-read-only (get-hash (user principal))
    (ok (map-get? registry user))
)
