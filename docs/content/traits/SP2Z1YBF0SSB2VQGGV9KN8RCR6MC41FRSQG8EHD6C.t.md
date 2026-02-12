---
title: "Trait t"
draft: true
---
```
(define-read-only (t1 (a uint) (b uint) (c uint))
  (or (is-eq a b) (is-eq c u1))
)

(define-read-only (t2 (a uint) (b uint) (c uint))
  (t1 a b)
)

```
