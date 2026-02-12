---
title: "Trait delegation-note"
draft: true
---
```
(define-map delegates principal principal)

(define-public (delegate (to principal))
  (begin (map-set delegates tx-sender to) (ok to))
)

```
