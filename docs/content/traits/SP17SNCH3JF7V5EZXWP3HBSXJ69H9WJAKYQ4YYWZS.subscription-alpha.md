---
title: "Trait subscription-alpha"
draft: true
---
```
;; Subscription management contract
(define-map subscriptions {user: principal, plan: (string-ascii 32)} {active: bool, expiry: uint})
(define-data-var subscription-price uint u100)

(define-read-only (is-subscribed (user principal) (plan (string-ascii 32)))
  (match (map-get? subscriptions {user: user, plan: plan})
    sub (>= (get expiry sub) burn-block-height)
    false
  )
)

(define-public (subscribe (plan (string-ascii 32)) (duration uint))
  (begin
    (asserts! (not (is-subscribed tx-sender plan)) (err u1))
    (map-set subscriptions {user: tx-sender, plan: plan} {
      active: true,
      expiry: (+ burn-block-height duration)
    })
    (ok true)
  )
)

(define-public (renew-subscription (plan (string-ascii 32)) (duration uint))
  (begin
    (asserts! (is-subscribed tx-sender plan) (err u2))
    (map-set subscriptions {user: tx-sender, plan: plan} {
      active: true,
      expiry: (+ burn-block-height duration)
    })
    (ok true)
  )
)

```
