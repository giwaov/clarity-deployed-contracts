;; Contract: Product Registry
;; Description: List of items that can be reviewed.

(define-map product-list uint (string-ascii 50))
(define-data-var last-id uint u0)

(define-public (register-product (name (string-ascii 50)))
    (let
        (
            (new-id (+ (var-get last-id) u1))
        )
        (map-set product-list new-id name)
        (var-set last-id new-id)
        (ok new-id)
    )
)

(define-read-only (item-exists (id uint))
    (ok (is-some (map-get? product-list id)))
)