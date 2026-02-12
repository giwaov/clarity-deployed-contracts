---
title: "Trait summer-winter"
draft: true
---
```
(define-data-var summer uint u0)
(define-data-var winter uint u0)

(define-public (vote-summer)
  (begin
    (var-set summer (+ (var-get summer) u1))
    (ok "Summer!")
  )
)

(define-public (vote-winter)
  (begin
    (var-set winter (+ (var-get winter) u1))
    (ok "Winter!")
  )
)

(define-read-only (season-results)
  {
    summer: (var-get summer),
    winter: (var-get winter)
  }
)

```
