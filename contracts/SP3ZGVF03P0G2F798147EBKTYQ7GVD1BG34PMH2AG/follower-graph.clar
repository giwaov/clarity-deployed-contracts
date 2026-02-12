;; Follower Graph
(define-map follows {follower: principal, following: principal} {since: uint})
(define-public (follow-user (following principal) (since uint))
  (begin (map-set follows {follower: tx-sender, following: following} {since: since}) (ok true)))
(define-read-only (is-following (follower principal) (following principal))
  (map-get? follows {follower: follower, following: following}))
