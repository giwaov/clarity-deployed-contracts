(define-map profiles principal {handle: (string-ascii 20), bio: (string-utf8 100)})

(define-public (set-profile (handle (string-ascii 20)) (bio (string-utf8 100)))
    (begin
        (map-set profiles tx-sender {handle: handle, bio: bio})
        (ok true)
    )
)

(define-read-only (get-profile (user principal))
    (ok (map-get? profiles user))
)
