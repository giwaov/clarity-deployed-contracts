---
title: "Trait nova-resource-marketplace"
draft: true
---
```

;; nova-resource-marketplace.clar
;; Trading resources
;; CLARITY VERSION: 2

(use-trait nova-trait-fungible .nova-trait-fungible.nova-trait-fungible)

(define-map listings
    uint
    {
        seller: principal,
        token: principal,
        amount: uint,
        price: uint
    }
)

(define-public (list-resource (id uint) (token <nova-trait-fungible>) (amount uint) (price uint))
    (begin
        ;; Transfer to vault logic omitted
        (map-set listings id {seller: tx-sender, token: (contract-of token), amount: amount, price: price})
        (ok true)
    )
)

```
