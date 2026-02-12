---
title: "Trait payment-splits"
draft: true
---
```
;; Payment Splits
(define-map splits {split-id: uint, recipient: principal} {percentage: uint, total-received: uint, last-payment: uint})
(define-public (set-split (split-id uint) (recipient principal) (percentage uint) (total-received uint) (last-payment uint))
  (begin (map-set splits {split-id: split-id, recipient: recipient} {percentage: percentage, total-received: total-received, last-payment: last-payment}) (ok true)))
(define-read-only (get-split (split-id uint) (recipient principal))
  (map-get? splits {split-id: split-id, recipient: recipient}))

```
