---
title: "Trait Access-Whitelist"
draft: true
---
```
(define-map whitelist principal bool)

(define-public (allow)
  (begin
    (map-set whitelist tx-sender true)
    (ok true)
  )
)

(define-read-only (allowed (user principal))
  (is-some (map-get? whitelist user))
)

```
