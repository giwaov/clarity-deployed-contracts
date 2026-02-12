---
title: "Trait membership-tiers"
draft: true
---
```
;; Membership Tiers
(define-map memberships {member: principal} {tier: (string-ascii 20), points: uint, joined-at: uint, expires-at: uint})
(define-public (set-membership (tier (string-ascii 20)) (points uint) (joined-at uint) (expires-at uint))
  (begin (map-set memberships {member: tx-sender} {tier: tier, points: points, joined-at: joined-at, expires-at: expires-at}) (ok true)))
(define-read-only (get-membership (member principal))
  (map-get? memberships {member: member}))

```
