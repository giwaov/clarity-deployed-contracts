---
title: "Trait proof-of-action"
draft: true
---
```
(define-map proofs principal uint)

(define-public (prove)
  (begin (map-set proofs tx-sender burn-block-height) (ok true))
)

```
