---
title: "Trait finality-flag"
draft: true
---
```
(define-map finalized principal bool)

(define-public (finalize)
  (begin (map-set finalized tx-sender true) (ok true))
)

```
