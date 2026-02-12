---
title: "Trait math-utils-v2"
draft: true
---
```
(define-read-only (safe-add (a uint) (b uint))
    (ok (+ a b))
)

(define-read-only (safe-multiply (a uint) (b uint))
    (ok (* a b))
)

```
