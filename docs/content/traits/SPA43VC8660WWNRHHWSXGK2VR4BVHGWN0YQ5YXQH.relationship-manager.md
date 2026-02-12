---
title: "Trait relationship-manager"
draft: true
---
```
;; relationship-manager.clar
;; Manages directional relationships between principals (e.g. following/trusting).
;; Simulates a simple social graph or trust registry.

(define-map relations { follower: principal, target: principal } bool)

(define-public (follow-user (target principal))
    (ok (map-set relations { follower: tx-sender, target: target } true))
)

(define-public (unfollow-user (target principal))
    (ok (map-set relations { follower: tx-sender, target: target } false))
)

(define-read-only (check-relation (follower principal) (target principal))
    (default-to false (map-get? relations { follower: follower, target: target }))
)

```
