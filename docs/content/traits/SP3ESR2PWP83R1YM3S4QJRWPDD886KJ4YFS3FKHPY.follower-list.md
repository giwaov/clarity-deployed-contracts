---
title: "Trait follower-list"
draft: true
---
```
;; Follower List

(define-map followers
  { creator: principal, follower: principal }
  { following: bool }
)

(define-map follower-counts
  principal
  { count: uint }
)

(define-public (follow (creator principal))
  (begin
    (asserts! (is-none (map-get? followers { creator: creator, follower: tx-sender })) (err u409))
    (map-set followers { creator: creator, follower: tx-sender } { following: true })
    (let ((current (default-to { count: u0 } (map-get? follower-counts creator))))
      (map-set follower-counts creator { count: (+ (get count current) u1) })
    )
    (ok true)
  )
)

(define-public (unfollow (creator principal))
  (begin
    (asserts! (is-some (map-get? followers { creator: creator, follower: tx-sender })) (err u404))
    (map-delete followers { creator: creator, follower: tx-sender })
    (let ((current (default-to { count: u1 } (map-get? follower-counts creator))))
      (map-set follower-counts creator { count: (- (get count current) u1) })
    )
    (ok true)
  )
)

(define-read-only (is-following (creator principal) (follower principal))
  (is-some (map-get? followers { creator: creator, follower: follower }))
)

(define-read-only (get-follower-count (creator principal))
  (default-to { count: u0 } (map-get? follower-counts creator))
)

```
