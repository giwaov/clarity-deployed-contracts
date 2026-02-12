;; ---------------------------------------------------------
;; Achievement Badges
;; Awards simple badges
;; ---------------------------------------------------------

(define-map badges principal uint)


(define-public (award (user principal))
    (let ((count (default-to u0 (map-get? badges user))))
        (map-set badges user (+ count u1))
        (ok (+ count u1))
    )
)
