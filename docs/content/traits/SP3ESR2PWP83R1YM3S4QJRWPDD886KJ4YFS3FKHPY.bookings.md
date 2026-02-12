---
title: "Trait bookings"
draft: true
---
```
;; Bookings
(define-map bookings uint {user: principal, service-id: uint, status: (string-ascii 20)})
(define-data-var booking-id uint u0)
(define-public (create-booking (service-id uint))
  (let ((id (var-get booking-id)))
    (map-set bookings id {user: tx-sender, service-id: service-id, status: "pending"})
    (var-set booking-id (+ id u1))
    (ok id)))
(define-read-only (get-booking (id uint))
  (map-get? bookings id))

```
