(define-map configs (string-ascii 50) (string-ascii 256))

(define-public (set-config (key (string-ascii 50)) (value (string-ascii 256)))
    (begin
        (map-set configs key value)
        (ok true)
    )
)

(define-read-only (get-config (key (string-ascii 50)))
    (ok (map-get? configs key))
)
