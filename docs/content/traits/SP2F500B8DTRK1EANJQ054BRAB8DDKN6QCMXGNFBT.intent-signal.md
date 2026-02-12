---
title: "Trait intent-signal"
draft: true
---
```
(define-map intents principal uint)

(define-public (signal (code uint))
  (begin
    (map-set intents tx-sender code)
    (ok code)
  )
)

```
