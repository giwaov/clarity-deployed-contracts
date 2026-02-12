(define-map messages uint (string-utf8 280))
(define-data-var msg-count uint u0)

(define-public (post-message (content (string-utf8 280)))
    (let ((id (+ (var-get msg-count) u1)))
        (map-set messages id content)
        (var-set msg-count id)
        (ok id)
    )
)

(define-read-only (get-message (id uint))
    (ok (map-get? messages id))
)
