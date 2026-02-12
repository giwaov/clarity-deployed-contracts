---
title: "Trait review-log"
draft: true
---
```
(define-map reviews principal uint)

(define-public (review)
  (begin (map-set reviews tx-sender burn-block-height) (ok true))
)

```
