---
title: "Trait nova-amm-router"
draft: true
---
```

;; nova-amm-router.clar
;; Routes swaps between pools
;; CLARITY VERSION: 2

(use-trait nova-trait-fungible .nova-trait-fungible.nova-trait-fungible)

(define-constant ERR-PATH-FAILED (err u100))

;; Simplified router that just does two hops
(define-public (swap-hop-2
    (token-a <nova-trait-fungible>)
    (token-b <nova-trait-fungible>)
    (token-c <nova-trait-fungible>)
    (amt-in uint)
    (min-out uint)
)
    ;; In a real implementation this would call individual pools
    ;; For now we just mock the concept of routing
    (ok true)
)

(define-read-only (get-quote (amt-in uint))
    (ok amt-in) ;; 1:1 oracle for mock
)

```
