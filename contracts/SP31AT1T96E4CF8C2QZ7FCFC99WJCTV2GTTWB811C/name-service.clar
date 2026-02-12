(define-map names (string-ascii 20) principal)

(define-public (register-name (name (string-ascii 20)))
    (begin
        (asserts! (is-none (map-get? names name)) (err u409))
        (map-set names name tx-sender)
        (ok true)
    )
)

(define-read-only (resolve-name (name (string-ascii 20)))
    (ok (map-get? names name))
)
