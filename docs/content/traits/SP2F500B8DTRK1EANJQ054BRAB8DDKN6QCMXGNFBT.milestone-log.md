---
title: "Trait milestone-log"
draft: true
---
```
(define-map milestones principal uint)

(define-public (advance (step uint))
  (begin
    (map-set milestones tx-sender step)
    (ok step)
  )
)

```
