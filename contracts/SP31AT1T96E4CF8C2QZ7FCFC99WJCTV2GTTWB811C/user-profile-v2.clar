(define-map user-profiles principal {
    username: (string-ascii 32),
    bio: (string-utf8 256),
    created-at: uint
})

(define-public (create-profile (username (string-ascii 32)) (bio (string-utf8 256)))
    (begin
        (map-set user-profiles tx-sender {
            username: username,
            bio: bio,
            created-at: stacks-block-height
        })
        (ok true)
    )
)

(define-read-only (get-profile (user principal))
    (ok (map-get? user-profiles user))
)
