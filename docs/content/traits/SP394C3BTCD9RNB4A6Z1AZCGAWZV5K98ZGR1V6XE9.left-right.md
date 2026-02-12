---
title: "Trait left-right"
draft: true
---
```
(define-data-var left-side uint u0)
(define-data-var right-side uint u0)

(define-public (choose-left)
  (begin
    (var-set left-side (+ (var-get left-side) u1))
    (ok "Left side")
  )
)

(define-public (choose-right)
  (begin
    (var-set right-side (+ (var-get right-side) u1))
    (ok "Right side")
  )
)

(define-read-only (direction-results)
  {
    left: (var-get left-side),
    right: (var-get right-side)
  }
)

```
