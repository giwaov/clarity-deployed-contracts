
;; nova-profile-metadata.clar
;; Extended profile data
;; CLARITY VERSION: 2

(define-map metadata
    principal
    {
        bio: (string-utf8 128),
        avatar: (string-ascii 128)
    }
)

(define-public (update-profile (bio (string-utf8 128)) (avatar (string-ascii 128)))
    (begin
        (map-set metadata tx-sender {bio: bio, avatar: avatar})
        (ok true)
    )
)
