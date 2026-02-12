---
title: "Trait Reputation"
draft: true
---
```
(define-map reputation principal uint)

(define-public (add-point)
  (let ((current (default-to u0 (map-get? reputation tx-sender))))
    (begin
      (map-set reputation tx-sender (+ current u1))
      (ok (+ current u1))
    )
  )
)

```
