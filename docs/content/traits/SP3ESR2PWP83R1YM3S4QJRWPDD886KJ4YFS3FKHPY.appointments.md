---
title: "Trait appointments"
draft: true
---
```
;; Appointments
(define-map appointments uint {client: principal, provider: principal, slot: uint})
(define-data-var appointment-id uint u0)
(define-public (book-appointment (provider principal) (slot uint))
  (let ((id (var-get appointment-id)))
    (map-set appointments id {client: tx-sender, provider: provider, slot: slot})
    (var-set appointment-id (+ id u1))
    (ok id)))
(define-read-only (get-appointment (id uint))
  (map-get? appointments id))

```
