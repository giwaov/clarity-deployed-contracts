(define-map kv-storage (string-ascii 64) (string-ascii 256))

(define-public (set-value (key (string-ascii 64)) (value (string-ascii 256)))
    (begin
        (map-set kv-storage key value)
        (ok true)
    )
)

(define-read-only (get-value (key (string-ascii 64)))
    (ok (map-get? kv-storage key))
)
