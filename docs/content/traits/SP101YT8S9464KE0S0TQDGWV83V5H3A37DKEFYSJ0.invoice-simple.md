---
title: "Trait invoice-simple"
draft: true
---
```
;; Simple Invoice - Create and pay invoices

(define-map invoices
  uint
  {
    creator: principal,
    customer: principal,
    amount: uint,
    paid: bool
  }
)

(define-data-var invoice-counter uint u0)

(define-public (create-invoice (customer principal) (amount uint))
  (let ((id (var-get invoice-counter)))
    (map-set invoices id {
      creator: tx-sender,
      customer: customer,
      amount: amount,
      paid: false
    })
    (var-set invoice-counter (+ id u1))
    (ok id)
  )
)

(define-public (pay-invoice (id uint))
  (let ((invoice (unwrap! (map-get? invoices id) (err u404))))
    (asserts! (is-eq tx-sender (get customer invoice)) (err u403))
    (asserts! (not (get paid invoice)) (err u400))
    (try! (stx-transfer? (get amount invoice) tx-sender (get creator invoice)))
    (map-set invoices id (merge invoice { paid: true }))
    (ok true)
  )
)

(define-read-only (get-invoice (id uint))
  (map-get? invoices id)
)

```
