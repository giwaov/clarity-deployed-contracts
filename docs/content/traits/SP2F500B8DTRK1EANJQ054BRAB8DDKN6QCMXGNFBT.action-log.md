---
title: "Trait action-log"
draft: true
---
```
(define-map actions principal uint)

(define-public (log)
  (begin
    (map-set actions tx-sender burn-block-height)
    (ok burn-block-height)
  )
)

(define-read-only (last-action (user principal))
  (map-get? actions user)
)

```
