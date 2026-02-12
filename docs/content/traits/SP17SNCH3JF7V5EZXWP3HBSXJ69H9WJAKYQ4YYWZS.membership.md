---
title: "Trait membership"
draft: true
---
```
;; Membership management contract
(define-map members {user: principal, tier: (string-ascii 32)} {active: bool, joined: uint})
(define-data-var total-members uint u0)
(define-map tier-requirements (string-ascii 32) uint)

(define-read-only (is-member (user principal) (tier (string-ascii 32)))
  (match (map-get? members {user: user, tier: tier})
    m (get active m)
    false
  )
)

(define-public (join-tier (tier (string-ascii 32)))
  (begin
    (asserts! (not (is-member tx-sender tier)) (err u1))
    (map-set members {user: tx-sender, tier: tier} {
      active: true,
      joined: burn-block-height
    })
    (ok (var-set total-members (+ (var-get total-members) u1)))
  )
)

(define-public (leave-tier (tier (string-ascii 32)))
  (begin
    (asserts! (is-member tx-sender tier) (err u2))
    (map-delete members {user: tx-sender, tier: tier})
    (ok (var-set total-members (- (var-get total-members) u1)))
  )
)

```
