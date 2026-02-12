---
title: "Trait category-manager"
draft: true
---
```
;; Category Manager

(define-map categories
  uint
  { owner: principal, name: (string-ascii 30), active: bool }
)

(define-data-var counter uint u0)

(define-public (add-category (name (string-ascii 30)))
  (let ((id (var-get counter)))
    (map-set categories id { owner: tx-sender, name: name, active: true })
    (var-set counter (+ id u1))
    (ok id)
  )
)

(define-public (rename-category (id uint) (name (string-ascii 30)))
  (let ((cat (unwrap! (map-get? categories id) (err u404))))
    (asserts! (is-eq (get owner cat) tx-sender) (err u403))
    (map-set categories id (merge cat { name: name }))
    (ok true)
  )
)

(define-public (disable-category (id uint))
  (let ((cat (unwrap! (map-get? categories id) (err u404))))
    (asserts! (is-eq (get owner cat) tx-sender) (err u403))
    (map-set categories id (merge cat { active: false }))
    (ok true)
  )
)

(define-read-only (get-category (id uint))
  (map-get? categories id)
)

```
