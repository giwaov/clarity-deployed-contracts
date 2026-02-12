---
title: "Trait inventory-items"
draft: true
---
```
;; Inventory Items
(define-map inventory {owner: principal, item-id: uint} {name: (string-ascii 50), quantity: uint})
(define-public (add-item (item-id uint) (name (string-ascii 50)) (quantity uint))
  (begin (map-set inventory {owner: tx-sender, item-id: item-id} {name: name, quantity: quantity}) (ok true)))
(define-read-only (get-item (owner principal) (item-id uint))
  (map-get? inventory {owner: owner, item-id: item-id}))

```
