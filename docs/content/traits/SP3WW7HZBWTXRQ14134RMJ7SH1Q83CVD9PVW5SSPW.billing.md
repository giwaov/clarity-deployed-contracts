---
title: "Trait billing"
draft: true
---
```
;; Billing Contract

(define-map payment-history
  { user: principal, subscription-id: uint }
  (list 100 uint)
)

(define-read-only (get-payment-history (user principal) (subscription-id uint))
  (default-to (list) (map-get? payment-history { user: user, subscription-id: subscription-id }))
)

(define-public (process-payment (subscription-id uint) (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (ok amount)
  )
)

```
