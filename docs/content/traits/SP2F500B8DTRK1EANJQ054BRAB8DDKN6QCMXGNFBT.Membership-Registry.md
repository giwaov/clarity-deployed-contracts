---
title: "Trait Membership-Registry"
draft: true
---
```
(define-map members principal bool)

(define-public (join)
  (begin
    (map-set members tx-sender true)
    (ok true)
  )
)

(define-read-only (is-member (user principal))
  (is-some (map-get? members user))
)

```
