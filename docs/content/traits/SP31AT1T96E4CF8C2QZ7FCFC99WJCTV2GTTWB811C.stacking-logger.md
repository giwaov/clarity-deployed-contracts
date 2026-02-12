---
title: "Trait stacking-logger"
draft: true
---
```
(define-map logs uint uint) ;; block -> amount

(define-public (log-stacking (amount uint))
    (begin
        (map-set logs stacks-block-height amount)
        (ok true)
    )
)

```
