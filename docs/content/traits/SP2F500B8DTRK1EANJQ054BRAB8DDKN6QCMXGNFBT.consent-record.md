---
title: "Trait consent-record"
draft: true
---
```
(define-map consent principal uint)

(define-public (consent-now)
  (begin
    (map-set consent tx-sender burn-block-height)
    (ok true)
  )
)

(define-read-only (has-consented (user principal))
  (is-some (map-get? consent user))
)

```
