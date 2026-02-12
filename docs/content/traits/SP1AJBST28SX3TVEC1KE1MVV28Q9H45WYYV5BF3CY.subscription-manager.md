---
title: "Trait subscription-manager"
draft: true
---
```
;; Subscription Manager
(define-map subscriptions {subscriber: principal, service-id: uint} {plan: (string-ascii 30), amount: uint, start-date: uint, end-date: uint})
(define-public (subscribe (service-id uint) (plan (string-ascii 30)) (amount uint) (start-date uint) (end-date uint))
  (begin (map-set subscriptions {subscriber: tx-sender, service-id: service-id} {plan: plan, amount: amount, start-date: start-date, end-date: end-date}) (ok true)))
(define-read-only (get-subscription (subscriber principal) (service-id uint))
  (map-get? subscriptions {subscriber: subscriber, service-id: service-id}))

```
