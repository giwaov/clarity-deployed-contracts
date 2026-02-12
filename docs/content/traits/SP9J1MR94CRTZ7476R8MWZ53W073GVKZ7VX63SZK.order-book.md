---
title: "Trait order-book"
draft: true
---
```
;; Order Book
(define-map orders {order-id: uint} {buyer: principal, seller: principal, amount: uint, price: uint, status: (string-ascii 20)})
(define-public (create-order (order-id uint) (seller principal) (amount uint) (price uint) (status (string-ascii 20)))
  (begin (map-set orders {order-id: order-id} {buyer: tx-sender, seller: seller, amount: amount, price: price, status: status}) (ok true)))
(define-read-only (get-order (order-id uint))
  (map-get? orders {order-id: order-id}))

```
