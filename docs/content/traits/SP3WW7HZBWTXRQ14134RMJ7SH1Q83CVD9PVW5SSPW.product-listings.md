---
title: "Trait product-listings"
draft: true
---
```
;; Product Listings

(define-data-var next-listing-id uint u1)

(define-map listings uint { seller: principal, product: (string-ascii 64), price: uint, active: bool })

(define-public (create-listing (product (string-ascii 64)) (price uint))
  (let ((listing-id (var-get next-listing-id)))
    (map-set listings listing-id { seller: tx-sender, product: product, price: price, active: true })
    (var-set next-listing-id (+ listing-id u1))
    (ok listing-id)
  )
)

```
