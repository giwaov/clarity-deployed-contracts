---
title: "Trait payment-tracker"
draft: true
---
```
;; Payment Tracker - Track payments
(define-map payments uint {payer: principal, amount: uint, reference: (string-ascii 50)})
(define-data-var payment-id uint u0)

(define-public (record-payment (amount uint) (reference (string-ascii 50)))
  (let ((id (var-get payment-id)))
    (map-set payments id {payer: tx-sender, amount: amount, reference: reference})
    (var-set payment-id (+ id u1))
    (ok id)))

(define-read-only (get-payment (id uint))
  (map-get? payments id))

```
