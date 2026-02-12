---
title: "Trait clarity-base"
draft: true
---
```
(define-data-var owner principal tx-sender)

(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) (err u100))
    (var-set owner new-owner)
    (ok true)
  )
)

(define-read-only (get-owner)
  (var-get owner)
)

```
