
;; nova-badge-registry.clar
;; Registry for badges
;; CLARITY VERSION: 2

(define-map badge-definitions
    uint
    (string-utf8 64)
)

(define-read-only (get-badge-name (id uint))
    (map-get? badge-definitions id)
)
