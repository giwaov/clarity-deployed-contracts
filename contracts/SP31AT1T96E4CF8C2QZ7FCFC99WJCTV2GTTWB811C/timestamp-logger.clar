(define-map logs uint uint)
(define-data-var log-id uint u0)

(define-public (log-time)
    (let ((id (+ (var-get log-id) u1)))
        (map-set logs id stacks-block-height)
        (var-set log-id id)
        (ok id)
    )
)

(define-read-only (get-log (id uint))
    (ok (map-get? logs id))
)
