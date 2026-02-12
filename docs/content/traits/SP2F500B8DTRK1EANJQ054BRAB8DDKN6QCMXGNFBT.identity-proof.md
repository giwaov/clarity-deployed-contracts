---
title: "Trait identity-proof"
draft: true
---
```
(define-map proofs principal bool)

(define-public (prove)
  (begin
    (map-set proofs tx-sender true)
    (ok true)
  )
)

(define-read-only (proved (user principal))
  (is-some (map-get? proofs user))
)

```
