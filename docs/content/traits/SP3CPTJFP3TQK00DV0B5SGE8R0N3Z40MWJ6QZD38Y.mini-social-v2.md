---
title: "Trait mini-social-v2"
draft: true
---
```
;; mini-social.clar
;; Follow logic

(define-map following { follower: principal, target: principal } bool)

(define-public (follow (target principal))
    (ok (map-set following { follower: tx-sender, target: target } true))
)

(define-public (unfollow (target principal))
    (ok (map-delete following { follower: tx-sender, target: target }))
)

```
