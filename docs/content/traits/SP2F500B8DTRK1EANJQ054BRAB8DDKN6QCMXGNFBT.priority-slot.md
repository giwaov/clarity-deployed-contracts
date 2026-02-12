---
title: "Trait priority-slot"
draft: true
---
```
(define-map priority principal uint)

(define-public (set (level uint))
  (begin (map-set priority tx-sender level) (ok level))
)

```
