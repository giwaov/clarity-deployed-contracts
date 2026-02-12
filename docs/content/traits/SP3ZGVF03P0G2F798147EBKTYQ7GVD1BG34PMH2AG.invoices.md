---
title: "Trait invoices"
draft: true
---
```
;; Invoices
(define-map invoices uint {issuer: principal, amount: uint, paid: bool})
(define-data-var invoice-id uint u0)
(define-public (create-invoice (amount uint))
  (let ((id (var-get invoice-id)))
    (map-set invoices id {issuer: tx-sender, amount: amount, paid: false})
    (var-set invoice-id (+ id u1))
    (ok id)))
(define-read-only (get-invoice (id uint))
  (map-get? invoices id))

```
