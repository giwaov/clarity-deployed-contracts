---
title: "Trait Usage-Counter-per-User"
draft: true
---
```
(define-map usage principal uint)

(define-public (use)
  (let ((u (default-to u0 (map-get? usage tx-sender))))
    (begin
      (map-set usage tx-sender (+ u u1))
      (ok (+ u u1))
    )
  )
)

```
