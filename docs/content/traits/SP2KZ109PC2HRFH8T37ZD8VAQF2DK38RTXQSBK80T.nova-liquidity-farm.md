---
title: "Trait nova-liquidity-farm"
draft: true
---
```

;; nova-liquidity-farm.clar
;; Staking LP tokens for rewards
;; CLARITY VERSION: 2

(use-trait nova-trait-fungible .nova-trait-fungible.nova-trait-fungible)

(define-map user-stake
    principal
    uint
)

(define-public (stake-lp (amount uint) (lp-token <nova-trait-fungible>))
    (let (
        (current (default-to u0 (map-get? user-stake tx-sender)))
    )
    (try! (contract-call? lp-token transfer amount tx-sender (as-contract tx-sender) none))
    (map-set user-stake tx-sender (+ current amount))
    (ok true))
)

(define-public (unstake-lp (amount uint) (lp-token <nova-trait-fungible>))
    (let (
        (current (default-to u0 (map-get? user-stake tx-sender)))
    )
    (asserts! (>= current amount) (err u100))
    (try! (as-contract (contract-call? lp-token transfer amount tx-sender tx-sender none)))
    (map-set user-stake tx-sender (- current amount))
    (ok true))
)

```
