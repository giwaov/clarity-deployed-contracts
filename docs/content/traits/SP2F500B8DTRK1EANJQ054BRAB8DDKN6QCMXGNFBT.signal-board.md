---
title: "Trait signal-board"
draft: true
---
```
(define-map signals principal uint)

(define-public (signal (code uint))
  (begin (map-set signals tx-sender code) (ok code))
)

```
