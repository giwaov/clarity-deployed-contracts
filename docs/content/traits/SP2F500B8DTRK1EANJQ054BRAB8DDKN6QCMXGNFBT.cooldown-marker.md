---
title: "Trait cooldown-marker"
draft: true
---
```
(define-map marks principal uint)

(define-public (mark)
  (begin
    (map-set marks tx-sender burn-block-height)
    (ok burn-block-height)
  )
)

```
