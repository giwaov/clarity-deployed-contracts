---
title: "Trait event-calendar"
draft: true
---
```
;; Event Calendar

(define-map events
  uint
  { owner: principal, title: (string-ascii 50), date: uint, active: bool }
)

(define-data-var counter uint u0)

(define-public (create-event (title (string-ascii 50)) (date uint))
  (let ((id (var-get counter)))
    (map-set events id { owner: tx-sender, title: title, date: date, active: true })
    (var-set counter (+ id u1))
    (ok id)
  )
)

(define-public (cancel-event (id uint))
  (let ((event (unwrap! (map-get? events id) (err u404))))
    (asserts! (is-eq (get owner event) tx-sender) (err u403))
    (map-set events id (merge event { active: false }))
    (ok true)
  )
)

(define-read-only (get-event (id uint))
  (map-get? events id)
)

```
