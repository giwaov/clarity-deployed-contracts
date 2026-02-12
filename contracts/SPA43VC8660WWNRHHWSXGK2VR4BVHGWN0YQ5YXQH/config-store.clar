;; config-store.clar
;; Stores application configuration settings
;; innocuous looking

(define-map config-settings 
    { key: (string-ascii 64) } 
    { value: (string-ascii 256), updated-at: uint }
)

(define-public (update-config (key (string-ascii 64)) (value (string-ascii 256)))
    (begin
        (map-set config-settings 
            { key: key } 
            { value: value, updated-at: burn-block-height }
        )
        (ok true)
    )
)

(define-read-only (get-config (key (string-ascii 64)))
    (map-get? config-settings { key: key })
)
