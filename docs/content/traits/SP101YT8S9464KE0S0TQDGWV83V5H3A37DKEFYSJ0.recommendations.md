---
title: "Trait recommendations"
draft: true
---
```
;; Recommendations
(define-map recommendations uint {recommender: principal, service-id: uint, reason: (string-ascii 200)})
(define-data-var recommendation-id uint u0)
(define-public (recommend (service-id uint) (reason (string-ascii 200)))
  (let ((id (var-get recommendation-id)))
    (map-set recommendations id {recommender: tx-sender, service-id: service-id, reason: reason})
    (var-set recommendation-id (+ id u1))
    (ok id)))
(define-read-only (get-recommendation (id uint))
  (map-get? recommendations id))

```
