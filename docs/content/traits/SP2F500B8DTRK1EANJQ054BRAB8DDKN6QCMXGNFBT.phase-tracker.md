---
title: "Trait phase-tracker"
draft: true
---
```
(define-data-var phase uint u1)

(define-public (advance)
  (begin (var-set phase (+ (var-get phase) u1)) (ok (var-get phase)))
)

```
