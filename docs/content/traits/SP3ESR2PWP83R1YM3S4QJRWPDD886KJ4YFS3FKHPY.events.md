---
title: "Trait events"
draft: true
---
```
;; Events
(define-map events uint {organizer: principal, title: (string-ascii 100), capacity: uint})
(define-data-var event-id uint u0)
(define-public (create-event (title (string-ascii 100)) (capacity uint))
  (let ((id (var-get event-id)))
    (map-set events id {organizer: tx-sender, title: title, capacity: capacity})
    (var-set event-id (+ id u1))
    (ok id)))
(define-read-only (get-event (id uint))
  (map-get? events id))

```
