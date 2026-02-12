---
title: "Trait flash-loan-record"
draft: true
---
```
(define-map flash-loans principal uint)

(define-public (record-loan (amount uint))
    (begin
        (map-set flash-loans tx-sender amount)
        (ok true)
    )
)

```
