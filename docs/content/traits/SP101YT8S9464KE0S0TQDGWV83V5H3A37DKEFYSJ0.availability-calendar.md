---
title: "Trait availability-calendar"
draft: true
---
```
;; Availability Calendar - Track availability
(define-map availability {user: principal, date: uint} {available: bool})

(define-public (set-availability (date uint) (available bool))
  (begin
    (map-set availability {user: tx-sender, date: date} {available: available})
    (ok true)))

(define-read-only (check-availability (user principal) (date uint))
  (map-get? availability {user: user, date: date}))

```
