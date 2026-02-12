---
title: "Trait lp-token"
draft: true
---
```
;; Contract: Liquidity Provider Token
;; Description: Represents the asset used in the pool.

(define-fungible-token lp-asset)

(define-public (faucet (amount uint))
    (ft-mint? lp-asset amount tx-sender)
)

(define-public (transfer (amount uint) (sender principal) (recipient principal))
    (ft-transfer? lp-asset amount sender recipient)
)
```
