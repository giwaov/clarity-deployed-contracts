---
title: "Trait feedback-slot"
draft: true
---
```
(define-map features principal bool)

(define-public (enable)
  (begin
    (map-set features tx-sender true)
    (ok true)
  )
)

(define-read-only (enabled (user principal))
  (is-some (map-get? features user))
)

```
