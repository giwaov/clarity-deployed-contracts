---
title: "Trait nonce-board"
draft: true
---
```
(define-map nonces principal uint)

(define-public (use-nonce (n uint))
  (begin
    (map-set nonces tx-sender n)
    (ok n)
  )
)

```
