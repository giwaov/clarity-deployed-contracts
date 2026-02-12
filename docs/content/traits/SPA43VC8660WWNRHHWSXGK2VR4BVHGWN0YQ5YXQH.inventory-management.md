---
title: "Trait inventory-management"
draft: true
---
```
;; inventory-management
;; Supply Chain Tracking System

(define-map shipments
  { id: uint }
  { sender: principal, receiver: principal, location: (string-ascii 64), status: (string-ascii 20) }
)

(define-map audit-trail
  { shipment-id: uint, timestamp: uint }
  { action: (string-ascii 20), actor: principal }
)

(define-public (create-shipment (id uint) (receiver principal) (location (string-ascii 64)))
  (ok (map-set shipments { id: id } 
    { sender: tx-sender, receiver: receiver, location: location, status: "created" }
  ))
)

(define-public (update-location (id uint) (new-location (string-ascii 64)))
  (let ((shipment (unwrap! (map-get? shipments { id: id }) (err u404))))
    (ok (map-set shipments { id: id }
      (merge shipment { location: new-location, status: "in-transit" })
    ))
  )
)

(define-public (complete-delivery (id uint))
  (let ((shipment (unwrap! (map-get? shipments { id: id }) (err u404))))
    (ok (map-set shipments { id: id }
      (merge shipment { status: "delivered" })
    ))
  )
)
```
