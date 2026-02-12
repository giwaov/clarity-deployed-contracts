---
title: "Trait booking-system"
draft: true
---
```
;; Booking System - Track bookings
(define-map bookings uint {client: principal, provider: principal, service-id: uint})
(define-data-var booking-id uint u0)

(define-public (create-booking (provider principal) (service-id uint))
  (let ((id (var-get booking-id)))
    (map-set bookings id {client: tx-sender, provider: provider, service-id: service-id})
    (var-set booking-id (+ id u1))
    (ok id)))

(define-read-only (get-booking (id uint))
  (map-get? bookings id))

```
