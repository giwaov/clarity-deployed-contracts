---
title: "Trait confidence-index"
draft: true
---
```
(define-map confidence principal uint)

(define-public (set (level uint))
  (begin (map-set confidence tx-sender level) (ok level))
)

```
