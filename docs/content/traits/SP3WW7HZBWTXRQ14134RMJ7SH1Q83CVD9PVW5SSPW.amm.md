---
title: "Trait amm"
draft: true
---
```
;; AMM Contract

(define-constant err-insufficient-liquidity (err u100))

(define-map liquidity-pools
  uint
  {
    total-liquidity: uint,
    yes-tokens: uint,
    no-tokens: uint
  }
)

(define-read-only (get-pool (market-id uint))
  (map-get? liquidity-pools market-id)
)

(define-public (add-liquidity (market-id uint) (amount uint))
  (let ((pool (default-to { total-liquidity: u0, yes-tokens: u0, no-tokens: u0 } (map-get? liquidity-pools market-id))))
    (map-set liquidity-pools market-id (merge pool { total-liquidity: (+ (get total-liquidity pool) amount) }))
    (ok amount)
  )
)

(define-public (swap (market-id uint) (amount uint))
  (ok amount)
)

```
