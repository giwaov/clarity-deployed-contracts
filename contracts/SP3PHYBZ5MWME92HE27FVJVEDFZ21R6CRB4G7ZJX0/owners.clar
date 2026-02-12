;; Contract: Owners Registry
;; Description: Manages vault owners.

(define-map owners principal bool)

(define-public (add-owner (user principal))
    (ok (map-set owners user true))
)

(define-read-only (is-owner (user principal))
    (default-to false (map-get? owners user))
)