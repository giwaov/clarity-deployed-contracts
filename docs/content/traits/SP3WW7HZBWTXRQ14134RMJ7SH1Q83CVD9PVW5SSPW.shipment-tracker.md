---
title: "Trait shipment-tracker"
draft: true
---
```
;; Shipment Tracker

(define-data-var next-shipment-id uint u1)

(define-map shipments uint { product-id: uint, location: (string-ascii 64), status: (string-ascii 32) })

(define-public (create-shipment (product-id uint) (location (string-ascii 64)))
  (let ((shipment-id (var-get next-shipment-id)))
    (map-set shipments shipment-id { product-id: product-id, location: location, status: "in-transit" })
    (var-set next-shipment-id (+ shipment-id u1))
    (ok shipment-id)
  )
)

```
