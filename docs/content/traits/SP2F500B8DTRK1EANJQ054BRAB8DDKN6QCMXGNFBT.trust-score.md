---
title: "Trait trust-score"
draft: true
---
```
(define-map scores principal uint)

(define-public (set-score (value uint))
  (begin (map-set scores tx-sender value) (ok value))
)

(define-read-only (get-score (user principal))
  (default-to u0 (map-get? scores user))
)

```
