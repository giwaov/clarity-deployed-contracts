---
title: "Trait registry"
draft: true
---
```
(define-map players principal bool)

(define-public (register)
  (begin
    (map-set players tx-sender true)
    (ok true)
  )
)

```
