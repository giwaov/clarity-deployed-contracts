(define-map events
    uint
    {
        user: principal,
        kind: (string-ascii 10),
    }
)
(define-data-var event-count uint u0)

(define-public (emit-event (kind (string-ascii 10)))
    (let ((id (+ (var-get event-count) u1)))
        (map-set events id {
            user: tx-sender,
            kind: kind,
        })
        (var-set event-count id)
        (ok id)
    )
)
