---
title: "Trait Donation-Log"
draft: true
---
```
(define-map donations principal uint)

(define-public (log-donation (amount uint))
  (begin
    (map-set donations tx-sender amount)
    (ok amount)
  )
)

```
