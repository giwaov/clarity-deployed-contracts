---
title: "Trait dark-or-light"
draft: true
---
```
(define-data-var light uint u0)
(define-data-var dark uint u0)

(define-public (vote-light)
  (begin
    (var-set light (+ (var-get light) u1))
    (ok "Light side")
  )
)

(define-public (vote-dark)
  (begin
    (var-set dark (+ (var-get dark) u1))
    (ok "Dark side")
  )
)

(define-read-only (current-score)
  {
    light: (var-get light),
    dark: (var-get dark)
  }
)

```
