---
title: "Trait st-dao-traits"
draft: true
---
```
(define-trait upgradable
  (
    (get-impl () (response (optional principal) uint))    
    (set-impl (principal) (response bool uint))

    (init (principal) (response bool uint))
  )
)

(define-trait proposal-script
  (
    (execute () (response bool uint))
  )
)

```
