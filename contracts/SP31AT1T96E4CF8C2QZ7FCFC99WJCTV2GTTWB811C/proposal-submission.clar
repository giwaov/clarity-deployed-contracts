(define-map proposals uint (string-ascii 50))
(define-data-var count uint u0)

(define-public (propose (title (string-ascii 50)))
    (let
        (
            (id (+ (var-get count) u1))
        )
        (map-set proposals id title)
        (var-set count id)
        (ok id)
    )
)

(define-read-only (get-proposal (id uint))
    (ok (map-get? proposals id))
)
