---
title: "Trait swap-router-v13"
draft: true
---
```
;; Swap Router Contract
;; Handles currency conversions for multi-currency support

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-swap-failed (err u700))
(define-constant err-slippage-exceeded (err u701))
(define-constant err-deadline-passed (err u702))
(define-constant err-invalid-amount (err u703))
(define-constant err-insufficient-output (err u704))

;; Maximum slippage: 2% (200 basis points)
(define-constant max-slippage u200)
(define-constant basis-points u10000)

;; Swap fee: 0.3% (30 basis points) - typical AMM fee
(define-constant swap-fee-bps u30)

;; Data tracking
(define-data-var total-swaps-executed uint u0)
(define-data-var total-volume-stx uint u0)
(define-data-var total-volume-sbtc uint u0)

(define-map swap-history
  { swap-id: uint }
  {
    user: principal,
    input-currency: (string-ascii 10),
    output-currency: (string-ascii 10),
    input-amount: uint,
    output-amount: uint,
    executed-at: uint
  }
)

;; Swap STX to sBTC
(define-public (swap-stx-to-sbtc 
    (stx-amount uint)
    (min-sbtc-out uint)
    (deadline uint))
  (let
    (
      (btc-stx-rate (unwrap! (contract-call? .multi-currency-oracle-v13 get-btc-stx-rate) err-swap-failed))
      (fee-amount (/ (* stx-amount swap-fee-bps) basis-points))
      (amount-after-fee (- stx-amount fee-amount))
      ;; Convert STX to sBTC: divide by rate, adjust decimals
      (sbtc-out (/ (* amount-after-fee u100) btc-stx-rate))
    )
    (asserts! (> stx-amount u0) err-invalid-amount)
    (asserts! (<= stacks-block-height deadline) err-deadline-passed)
    (asserts! (>= sbtc-out min-sbtc-out) err-slippage-exceeded)
    
    ;; Transfer STX from user to contract
    (try! (stx-transfer? stx-amount tx-sender (as-contract tx-sender)))
    
    ;; Transfer sBTC from contract to user
    (try! (as-contract (contract-call? .sbtc-wrapper-v13 transfer-internal sbtc-out tx-sender)))
    
    ;; Record swap
    (let ((swap-id (var-get total-swaps-executed)))
      (map-set swap-history
        { swap-id: swap-id }
        {
          user: tx-sender,
          input-currency: "STX",
          output-currency: "sBTC",
          input-amount: stx-amount,
          output-amount: sbtc-out,
          executed-at: stacks-block-height
        }
      )
      (var-set total-swaps-executed (+ swap-id u1))
    )
    
    ;; Update volumes
    (var-set total-volume-stx (+ (var-get total-volume-stx) stx-amount))
    (var-set total-volume-sbtc (+ (var-get total-volume-sbtc) sbtc-out))
    
    (ok sbtc-out)
  )
)

;; Swap sBTC to STX
(define-public (swap-sbtc-to-stx
    (sbtc-amount uint)
    (min-stx-out uint)
    (deadline uint))
  (let
    (
      (btc-stx-rate (unwrap! (contract-call? .multi-currency-oracle-v13 get-btc-stx-rate) err-swap-failed))
      ;; Convert sBTC to STX: multiply by rate, adjust decimals
      (stx-before-fee (/ (* sbtc-amount btc-stx-rate) u100))
      (fee-amount (/ (* stx-before-fee swap-fee-bps) basis-points))
      (stx-out (- stx-before-fee fee-amount))
    )
    (asserts! (> sbtc-amount u0) err-invalid-amount)
    (asserts! (<= stacks-block-height deadline) err-deadline-passed)
    (asserts! (>= stx-out min-stx-out) err-slippage-exceeded)
    
    ;; Transfer sBTC from user to contract
    (try! (contract-call? .sbtc-wrapper-v13 transfer-internal sbtc-amount (as-contract tx-sender)))
    
    ;; Transfer STX from contract to user
    (try! (as-contract (stx-transfer? stx-out tx-sender tx-sender)))
    
    ;; Record swap
    (let ((swap-id (var-get total-swaps-executed)))
      (map-set swap-history
        { swap-id: swap-id }
        {
          user: tx-sender,
          input-currency: "sBTC",
          output-currency: "STX",
          input-amount: sbtc-amount,
          output-amount: stx-out,
          executed-at: stacks-block-height
        }
      )
      (var-set total-swaps-executed (+ swap-id u1))
    )
    
    (var-set total-volume-stx (+ (var-get total-volume-stx) stx-out))
    (var-set total-volume-sbtc (+ (var-get total-volume-sbtc) sbtc-amount))
    
    (ok stx-out)
  )
)

;; Quote functions (no state changes)
(define-read-only (quote-stx-to-sbtc (stx-amount uint))
  (let
    (
      (btc-stx-rate (unwrap-panic (contract-call? .multi-currency-oracle-v13 get-btc-stx-rate)))
      (fee-amount (/ (* stx-amount swap-fee-bps) basis-points))
      (amount-after-fee (- stx-amount fee-amount))
      (sbtc-out (/ (* amount-after-fee u100) btc-stx-rate))
    )
    (ok sbtc-out)
  )
)

(define-read-only (quote-sbtc-to-stx (sbtc-amount uint))
  (let
    (
      (btc-stx-rate (unwrap-panic (contract-call? .multi-currency-oracle-v13 get-btc-stx-rate)))
      (stx-before-fee (/ (* sbtc-amount btc-stx-rate) u100))
      (fee-amount (/ (* stx-before-fee swap-fee-bps) basis-points))
      (stx-out (- stx-before-fee fee-amount))
    )
    (ok stx-out)
  )
)

;; Calculate minimum output with slippage tolerance
(define-read-only (calculate-min-output (amount uint) (slippage-bps uint))
  (let
    ((slippage-amount (/ (* amount slippage-bps) basis-points)))
    (ok (- amount slippage-amount))
  )
)

;; Read-only stats
(define-read-only (get-swap-stats)
  (ok {
    total-swaps: (var-get total-swaps-executed),
    total-volume-stx: (var-get total-volume-stx),
    total-volume-sbtc: (var-get total-volume-sbtc)
  })
)

(define-read-only (get-swap-details (swap-id uint))
  (ok (map-get? swap-history { swap-id: swap-id }))
)

```
