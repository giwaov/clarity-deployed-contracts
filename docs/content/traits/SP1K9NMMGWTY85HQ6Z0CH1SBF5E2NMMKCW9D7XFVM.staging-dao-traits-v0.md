---
title: "Trait staging-dao-traits-v0"
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
