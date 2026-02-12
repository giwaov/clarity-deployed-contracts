(define-map timestamps principal {
    action: (string-ascii 50),
    timestamp: uint,
    block-height: uint
})

(define-public (log-timestamp (action (string-ascii 50)))
    (begin
        (map-set timestamps tx-sender {
            action: action,
            timestamp: stacks-block-height,
            block-height: stacks-block-height
        })
        (ok true)
    )
)

(define-read-only (get-timestamp (user principal))
    (ok (map-get? timestamps user))
)
