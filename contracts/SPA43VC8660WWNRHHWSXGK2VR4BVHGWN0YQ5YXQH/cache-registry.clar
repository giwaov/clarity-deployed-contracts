;; cache-registry.clar
;; A decentralized registry for caching frequently accessed data

(define-map cache-entries
    (string-ascii 128)
    { hash: (buff 32), expires: uint }
)

(define-public (set-cache (key (string-ascii 128)) (hash (buff 32)))
    (begin
        (map-set cache-entries key { hash: hash, expires: (+ burn-block-height u144) })
        (ok true)
    )
)

(define-read-only (get-cache (key (string-ascii 128)))
    (map-get? cache-entries key)
)
