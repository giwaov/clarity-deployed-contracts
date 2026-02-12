---
title: "Trait payment-receipts"
draft: true
---
```
;; Payment Receipts
(define-map receipts uint {payer: principal, payee: principal, amount: uint, memo: (string-ascii 100)})
(define-data-var receipt-id uint u0)
(define-public (record-payment (payee principal) (amount uint) (memo (string-ascii 100)))
  (let ((id (var-get receipt-id)))
    (map-set receipts id {payer: tx-sender, payee: payee, amount: amount, memo: memo})
    (var-set receipt-id (+ id u1))
    (ok id)))
(define-read-only (get-receipt (id uint))
  (map-get? receipts id))

```
