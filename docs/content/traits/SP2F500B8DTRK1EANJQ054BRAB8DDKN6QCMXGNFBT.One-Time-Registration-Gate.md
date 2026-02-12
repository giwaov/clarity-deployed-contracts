---
title: "Trait One-Time-Registration-Gate"
draft: true
---
```
(define-map registered principal bool)
(define-constant err-already (err u100))

(define-public (register)
  (if (is-some (map-get? registered tx-sender))
      err-already
      (begin
        (map-set registered tx-sender true)
        (ok true)
      )
  )
)

```
