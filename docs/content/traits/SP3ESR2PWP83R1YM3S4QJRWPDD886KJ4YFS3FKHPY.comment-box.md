---
title: "Trait comment-box"
draft: true
---
```
;; Comment Box

(define-map comments
  uint
  { author: principal, content: (string-ascii 200), visible: bool }
)

(define-data-var counter uint u0)

(define-public (add-comment (content (string-ascii 200)))
  (let ((id (var-get counter)))
    (map-set comments id { author: tx-sender, content: content, visible: true })
    (var-set counter (+ id u1))
    (ok id)
  )
)

(define-public (hide-comment (id uint))
  (let ((comment (unwrap! (map-get? comments id) (err u404))))
    (asserts! (is-eq (get author comment) tx-sender) (err u403))
    (map-set comments id (merge comment { visible: false }))
    (ok true)
  )
)

(define-read-only (get-comment (id uint))
  (map-get? comments id)
)

```
