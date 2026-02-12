(define-map name-registry (string-ascii 48) principal)

(define-constant err-name-taken (err u300))
(define-constant err-not-owner (err u301))

(define-public (register-name (name (string-ascii 48)))
    (begin
        (asserts! (is-none (map-get? name-registry name)) err-name-taken)
        (map-set name-registry name tx-sender)
        (ok true)
    )
)

(define-read-only (resolve-name (name (string-ascii 48)))
    (ok (map-get? name-registry name))
)

(define-read-only (get-owner (name (string-ascii 48)))
    (ok (map-get? name-registry name))
)
