---
title: "Trait liquidity-pool-v1"
draft: true
---
```
;; liquidity-pool-v1.clar
;; Constant product formula stub

(define-data-var token-x-reserve uint u0)
(define-data-var token-y-reserve uint u0)

(define-public (swap-x-for-y (amount-x uint))
    (let
        (
            (in-x amount-x)
            (res-x (var-get token-x-reserve))
            (res-y (var-get token-y-reserve))
            (out-y (/ (* in-x res-y) (+ res-x in-x)))
        )
        (asserts! (> amount-x u0) (err u100))
        ;; Transfer logic here
        (var-set token-x-reserve (+ res-x in-x))
        (var-set token-y-reserve (- res-y out-y))
        (ok out-y)
    )
)

```
