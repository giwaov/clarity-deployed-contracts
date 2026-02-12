;; allow-list.clar
;; Simple address whitelist

(define-map allowed principal bool)

(define-public (allow (user principal))
    ;; In reality check admin
    (ok (map-set allowed user true))
)

(define-read-only (is-allowed (user principal))
    (default-to false (map-get? allowed user))
)
