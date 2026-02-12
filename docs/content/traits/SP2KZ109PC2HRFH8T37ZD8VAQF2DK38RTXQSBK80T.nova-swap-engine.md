---
title: "Trait nova-swap-engine"
draft: true
---
```

;; nova-swap-engine.clar
;; A basic AMM-like swap contract for STX and a Nova Fungible Token.
;; CLARITY VERSION: 2

(use-trait nova-trait-fungible .nova-trait-fungible.nova-trait-fungible)

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-LIQUIDITY (err u101))
(define-constant ERR-SLIPPAGE-EXCEEDED (err u102))

(define-data-var liquidity-stx uint u0)
(define-data-var liquidity-token uint u0)
(define-data-var fee-basis-points uint u30) ;; 0.3% fee

;; Provide initial liquidity
(define-public (provide-liquidity (stx-amount uint) (token-amount uint) (token-trait <nova-trait-fungible>))
    (let (
        (sender tx-sender)
    )
    (try! (stx-transfer? stx-amount sender (as-contract tx-sender)))
    (try! (contract-call? token-trait transfer token-amount sender (as-contract tx-sender) none))
    
    (var-set liquidity-stx (+ (var-get liquidity-stx) stx-amount))
    (var-set liquidity-token (+ (var-get liquidity-token) token-amount))
    (ok true))
)

;; Swap STX for Token
(define-public (swap-stx-for-token (stx-amount uint) (min-token-out uint) (token-trait <nova-trait-fungible>))
    (let (
        (stx-in-with-fee (* stx-amount (- u10000 (var-get fee-basis-points))))
        (stx-reserve (var-get liquidity-stx))
        (token-reserve (var-get liquidity-token))
        (numerator (* stx-in-with-fee token-reserve))
        (denominator (+ (* stx-reserve u10000) stx-in-with-fee))
        (token-out (/ numerator denominator))
        (sender tx-sender)
    )
    (asserts! (>= token-out min-token-out) ERR-SLIPPAGE-EXCEEDED)
    (asserts! (> token-out u0) ERR-INVALID-LIQUIDITY)

    (try! (stx-transfer? stx-amount sender (as-contract tx-sender)))
    (try! (as-contract (contract-call? token-trait transfer token-out tx-sender sender none)))

    (var-set liquidity-stx (+ stx-reserve stx-amount))
    (var-set liquidity-token (- token-reserve token-out))
    (ok token-out))
)

;; Swap Token for STX
(define-public (swap-token-for-stx (token-amount uint) (min-stx-out uint) (token-trait <nova-trait-fungible>))
    (let (
        (token-in-with-fee (* token-amount (- u10000 (var-get fee-basis-points))))
        (stx-reserve (var-get liquidity-stx))
        (token-reserve (var-get liquidity-token))
        (numerator (* token-in-with-fee stx-reserve))
        (denominator (+ (* token-reserve u10000) token-in-with-fee))
        (stx-out (/ numerator denominator))
        (sender tx-sender)
    )
    (asserts! (>= stx-out min-stx-out) ERR-SLIPPAGE-EXCEEDED)
    (asserts! (> stx-out u0) ERR-INVALID-LIQUIDITY)

    (try! (contract-call? token-trait transfer token-amount sender (as-contract tx-sender) none))
    (try! (as-contract (stx-transfer? stx-out tx-sender sender)))

    (var-set liquidity-token (+ token-reserve token-amount))
    (var-set liquidity-stx (- stx-reserve stx-out))
    (ok stx-out))
)

(define-read-only (get-liquidity)
    (ok {
        stx: (var-get liquidity-stx),
        token: (var-get liquidity-token)
    })
)

```
