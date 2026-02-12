---
title: "Trait checkpoint-store"
draft: true
---
```
(define-map checkpoints principal uint)

(define-public (checkpoint)
  (begin
    (map-set checkpoints tx-sender burn-block-height)
    (ok burn-block-height)
  )
)

```
