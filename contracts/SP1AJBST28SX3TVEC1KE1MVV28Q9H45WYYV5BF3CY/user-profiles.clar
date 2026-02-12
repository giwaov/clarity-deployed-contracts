;; User Profiles
(define-map profiles {user: principal} {username: (string-ascii 50), bio: (string-ascii 200), created-at: uint})
(define-public (set-profile (username (string-ascii 50)) (bio (string-ascii 200)) (created-at uint))
  (begin (map-set profiles {user: tx-sender} {username: username, bio: bio, created-at: created-at}) (ok true)))
(define-read-only (get-profile (user principal))
  (map-get? profiles {user: user}))
