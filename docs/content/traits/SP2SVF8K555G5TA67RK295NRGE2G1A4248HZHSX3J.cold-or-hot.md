---
title: "Trait cold-or-hot"
draft: true
---
```
(define-data-var hot-count uint u0)
(define-data-var cold-count uint u0)

(define-public (vote-hot)
  (begin
    (var-set hot-count (+ (var-get hot-count) u1))
    (ok "Hot selected")
  )
)

(define-public (vote-cold)
  (begin
    (var-set cold-count (+ (var-get cold-count) u1))
    (ok "Cold selected")
  )
)

(define-read-only (get-temperature-results)
  {
    hot: (var-get hot-count),
    cold: (var-get cold-count)
  }
)

```
