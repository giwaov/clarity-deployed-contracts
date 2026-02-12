---
title: "Trait product-catalog"
draft: true
---
```
;; Product Catalog
(define-map products uint {seller: principal, name: (string-ascii 50), price: uint})
(define-data-var product-id uint u0)
(define-public (add-product (name (string-ascii 50)) (price uint))
  (let ((id (var-get product-id)))
    (map-set products id {seller: tx-sender, name: name, price: price})
    (var-set product-id (+ id u1))
    (ok id)))
(define-read-only (get-product (id uint))
  (map-get? products id))

```
