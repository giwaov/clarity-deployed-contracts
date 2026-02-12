---
title: "Trait booking-system"
draft: true
---
```
;; Booking System
(define-map bookings {booking-id: uint} {guest: principal, resource: (string-ascii 100), start-time: uint, end-time: uint, confirmed: bool})
(define-public (create-booking (booking-id uint) (resource (string-ascii 100)) (start-time uint) (end-time uint) (confirmed bool))
  (begin (map-set bookings {booking-id: booking-id} {guest: tx-sender, resource: resource, start-time: start-time, end-time: end-time, confirmed: confirmed}) (ok true)))
(define-read-only (get-booking (booking-id uint))
  (map-get? bookings {booking-id: booking-id}))

```
