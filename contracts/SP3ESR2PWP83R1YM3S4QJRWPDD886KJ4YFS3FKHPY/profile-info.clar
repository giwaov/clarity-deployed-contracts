;; Profile Info

(define-map profiles
  principal
  { name: (string-ascii 50), bio: (string-ascii 100) }
)

(define-public (set-profile (name (string-ascii 50)) (bio (string-ascii 100)))
  (begin
    (map-set profiles tx-sender { name: name, bio: bio })
    (ok true)
  )
)

(define-public (clear-profile)
  (begin
    (map-delete profiles tx-sender)
    (ok true)
  )
)

(define-read-only (get-profile (user principal))
  (map-get? profiles user)
)
