---
title: "Trait liquidity-pools"
draft: true
---
```
;; Liquidity Pools
;; AMM liquidity pools

(define-constant contract-owner tx-sender)

(define-map pools
  uint
  {
    token-a: uint,
    token-b: uint,
    total-liquidity: uint
  }
)

(define-read-only (get-pool (pool-id uint))
  (map-get? pools pool-id)
)

(define-public (add-liquidity (pool-id uint) (amount-a uint) (amount-b uint))
  (let ((pool (default-to { token-a: u0, token-b: u0, total-liquidity: u0 } (map-get? pools pool-id))))
    (map-set pools pool-id {
      token-a: (+ (get token-a pool) amount-a),
      token-b: (+ (get token-b pool) amount-b),
      total-liquidity: (+ (get total-liquidity pool) amount-a)
    })
    (ok amount-a)
  )
)

(define-public (swap (pool-id uint) (amount-in uint))
  (ok amount-in)
)

```
