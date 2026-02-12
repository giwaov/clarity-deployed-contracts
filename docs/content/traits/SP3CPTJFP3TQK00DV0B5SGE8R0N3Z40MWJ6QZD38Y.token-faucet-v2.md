---
title: "Trait token-faucet-v2"
draft: true
---
```
;; token-faucet.clar
;; Drip tokens

(define-map last-claim principal uint)
(define-constant COOLDOWN u100)
(define-constant AMOUNT u10)

(define-public (claim)
    (let
        (
            (last (default-to u0 (map-get? last-claim tx-sender)))
        )
        (asserts! (> block-height (+ last COOLDOWN)) (err u100))
        (map-set last-claim tx-sender block-height)
        (try! (stx-transfer? AMOUNT (as-contract tx-sender) tx-sender))
        (ok true)
    )
)

(define-public (fund (amount uint))
    (stx-transfer? amount tx-sender (as-contract tx-sender))
)

```
