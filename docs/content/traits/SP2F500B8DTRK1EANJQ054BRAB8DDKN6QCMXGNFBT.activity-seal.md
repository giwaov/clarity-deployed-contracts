---
title: "Trait activity-seal"
draft: true
---
```
(define-map seals principal uint)

(define-public (seal)
  (begin (map-set seals tx-sender burn-block-height) (ok true))
)

```
