---
title: "Trait cat-or-dogs"
draft: true
---
```
(define-data-var cats uint u0)
(define-data-var dogs uint u0)

(define-public (vote-cats)
  (begin
    (var-set cats (+ (var-get cats) u1))
    (ok "Cats!")
  )
)

(define-public (vote-dogs)
  (begin
    (var-set dogs (+ (var-get dogs) u1))
    (ok "Dogs!")
  )
)

(define-read-only (pet-results)
  {
    cats: (var-get cats),
    dogs: (var-get dogs)
  }
)

```
