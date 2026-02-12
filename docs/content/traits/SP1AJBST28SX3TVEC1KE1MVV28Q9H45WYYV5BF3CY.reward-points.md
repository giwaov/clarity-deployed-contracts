---
title: "Trait reward-points"
draft: true
---
```
;; Reward Points
(define-map rewards {user: principal} {points: uint, lifetime-earned: uint, last-updated: uint})
(define-public (update-rewards (points uint) (lifetime-earned uint) (last-updated uint))
  (begin (map-set rewards {user: tx-sender} {points: points, lifetime-earned: lifetime-earned, last-updated: last-updated}) (ok true)))
(define-read-only (get-rewards (user principal))
  (map-get? rewards {user: user}))

```
