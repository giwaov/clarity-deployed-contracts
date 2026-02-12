---
title: "Trait access-pass"
draft: true
---
```
(define-map passes principal uint)

(define-public (grant (expiry uint))
  (begin
    (map-set passes tx-sender expiry)
    (ok expiry)
  )
)

(define-read-only (is-valid (user principal))
  (match (map-get? passes user)
    exp (> exp burn-block-height)
    false
  )
)

```
