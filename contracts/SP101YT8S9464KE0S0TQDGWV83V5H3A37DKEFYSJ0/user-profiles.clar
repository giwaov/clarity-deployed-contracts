;; User Profiles - Manage user profiles

(define-map profiles
  principal
  {
    username: (string-ascii 50),
    bio: (string-utf8 200),
    created-at: uint
  }
)

(define-public (create-profile (username (string-ascii 50)) (bio (string-utf8 200)))
  (begin
    (map-set profiles tx-sender {
      username: username,
      bio: bio,
      created-at: stacks-block-height
    })
    (ok true)
  )
)

(define-public (update-bio (bio (string-utf8 200)))
  (let ((profile (unwrap! (map-get? profiles tx-sender) (err u404))))
    (map-set profiles tx-sender (merge profile { bio: bio }))
    (ok true)
  )
)

(define-read-only (get-profile (user principal))
  (map-get? profiles user)
)
