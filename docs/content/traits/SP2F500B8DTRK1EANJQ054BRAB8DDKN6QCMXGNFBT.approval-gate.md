---
title: "Trait approval-gate"
draft: true
---
```
(define-map approvals principal bool)

(define-public (approve)
  (begin
    (map-set approvals tx-sender true)
    (ok true)
  )
)

(define-read-only (approved (user principal))
  (is-some (map-get? approvals user))
)

```
