---
title: "Trait subscription-manager"
draft: true
---
```
;; Subscription Manager Contract

(define-data-var next-subscription-id uint u1)

(define-map subscriptions
  uint
  {
    subscriber: principal,
    tier: uint,
    price: uint,
    start-block: uint,
    active: bool
  }
)

(define-read-only (get-subscription (subscription-id uint))
  (map-get? subscriptions subscription-id)
)

(define-public (create-subscription (tier uint) (price uint))
  (let ((subscription-id (var-get next-subscription-id)))
    (map-set subscriptions subscription-id {
      subscriber: tx-sender,
      tier: tier,
      price: price,
      start-block: block-height,
      active: true
    })
    (var-set next-subscription-id (+ subscription-id u1))
    (ok subscription-id)
  )
)

(define-public (cancel-subscription (subscription-id uint))
  (let ((subscription (unwrap! (map-get? subscriptions subscription-id) (err u100))))
    (map-set subscriptions subscription-id (merge subscription { active: false }))
    (ok true)
  )
)

```
