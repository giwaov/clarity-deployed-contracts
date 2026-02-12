---
title: "Trait stacks-index-oneclick-v18"
draft: true
---
```
;; =====================================================================
;; StacksIndex OneClick V18 - 2 Token Support (STX + sBTC)
;; =====================================================================
;;
;; V18: Uses correct Bitflow contracts based on SDK analysis
;; - STX:  2-step via stableswap-core + xyk-swap-helper-v-1-3
;; - sBTC: 3-hop via router-stableswap-xyk-multihop-v-1-2 (swap-helper-b)
;;
;; Routes:
;; - STX:  USDCx -> aeUSDC (stableswap-core) -> STX (xyk-swap-helper)
;; - sBTC: USDCx -> aeUSDC (stableswap) -> STX (xyk) -> sBTC (xyk)
;;
;; =====================================================================

;; =====================
;; TRAITS
;; =====================

;; Bitflow SIP-010 trait
(use-trait ft-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)

;; Bitflow pool traits
;; stableswap-core-v-1-2 expects v-1-2 trait (for STX leg)
(use-trait stableswap-pool-trait-v12 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-2.stableswap-pool-trait)
;; router-stableswap-xyk-multihop-v-1-2 expects v-1-4 trait (for sBTC leg)
(use-trait stableswap-pool-trait-v14 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-4.stableswap-pool-trait)
;; XYK pool traits - v1.2 for xyk-swap-helper-v-1-3 and multihop router
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)

;; =====================
;; CONSTANTS
;; =====================

(define-constant CONTRACT-OWNER tx-sender)

;; Bitflow Contracts
;; Stableswap core for USDCx -> aeUSDC
(define-constant STABLESWAP-CORE 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-core-v-1-2)
;; XYK swap helper for aeUSDC -> STX (single XYK hop)
(define-constant XYK-SWAP-HELPER 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-swap-helper-v-1-3)
;; Router multihop v1.2 for 3-hop (stableswap + 2 XYK) - used for sBTC
(define-constant BITFLOW-ROUTER-MULTIHOP 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u1001))
(define-constant ERR-INVALID-AMOUNT (err u1002))
(define-constant ERR-SWAP-FAILED (err u1004))
(define-constant ERR-TRANSFER-FAILED (err u1005))
(define-constant ERR-CONTRACT-PAUSED (err u1007))
(define-constant ERR-MIN-INVESTMENT (err u1010))

;; Configuration
(define-constant BP-DENOMINATOR u10000)
(define-constant MIN-INVESTMENT u100000) ;; 0.1 USDCx (6 decimals)
(define-constant MAX-FEE u100) ;; 1% max

;; =====================
;; DATA VARIABLES
;; =====================

(define-data-var contract-paused bool false)
(define-data-var platform-fee-bp uint u0)
(define-data-var fee-recipient principal CONTRACT-OWNER)
(define-data-var total-investments uint u0)
(define-data-var total-volume uint u0)

;; =====================
;; READ-ONLY FUNCTIONS
;; =====================

(define-read-only (get-contract-info)
  {
    paused: (var-get contract-paused),
    fee-bp: (var-get platform-fee-bp),
    total-investments: (var-get total-investments),
    total-volume: (var-get total-volume),
    min-investment: MIN-INVESTMENT
  }
)

(define-read-only (calculate-fee (amount uint))
  (/ (* amount (var-get platform-fee-bp)) BP-DENOMINATOR)
)

;; =====================
;; PRIVATE FUNCTIONS
;; =====================

;; Execute stableswap: USDCx -> aeUSDC
;; Uses stableswap-core-v-1-2 swap-x-for-y (requires v-1-2 trait)
(define-private (execute-stableswap
    (amount uint)
    (min-out uint)
    (token-x <ft-trait>)
    (token-y <ft-trait>)
    (pool <stableswap-pool-trait-v12>)
  )
  (contract-call? STABLESWAP-CORE swap-x-for-y
    pool
    token-x
    token-y
    amount
    min-out
  )
)

;; Execute XYK swap via xyk-swap-helper-v-1-3 swap-helper-a
;; Uses the BITFLOW_XYK_XY_2 route pattern
(define-private (execute-xyk-swap
    (amount uint)
    (min-out uint)
    (token-a <ft-trait>)
    (token-b <ft-trait>)
    (pool <xyk-pool-trait>)
  )
  (contract-call? XYK-SWAP-HELPER swap-helper-a
    amount
    min-out
    none  ;; provider
    { a: token-a, b: token-b }
    { a: pool }
  )
)

;; Execute 3-hop swap via router multihop v1.2 (swap-helper-b)
;; Route: stableswap + 2 XYK hops
;; Used for: sBTC (USDCx -> aeUSDC -> STX -> sBTC)
;; Note: multihop router requires v-1-4 stableswap trait
(define-private (execute-swap-3hop
    (amount uint)
    (min-out uint)
    (ss-token-a <ft-trait>)
    (ss-token-b <ft-trait>)
    (ss-pool <stableswap-pool-trait-v14>)
    (xyk-token-a <ft-trait>)
    (xyk-token-b <ft-trait>)
    (xyk-token-c <ft-trait>)
    (xyk-token-d <ft-trait>)
    (xyk-pool-a <xyk-pool-trait>)
    (xyk-pool-b <xyk-pool-trait>)
  )
  (contract-call? BITFLOW-ROUTER-MULTIHOP swap-helper-b
    amount
    min-out
    none       ;; provider
    false      ;; swaps-reversed
    { a: ss-token-a, b: ss-token-b }
    { a: ss-pool }
    { a: xyk-token-a, b: xyk-token-b, c: xyk-token-c, d: xyk-token-d }
    { a: xyk-pool-a, b: xyk-pool-b }
  )
)

;; =====================
;; PUBLIC FUNCTIONS
;; =====================

;; Main investment function - 2 tokens:
;; - STX: 2-step via stableswap-core + xyk-swap-helper
;; - sBTC: 3-hop via router multihop v1.2 (swap-helper-b)
;;
;; Frontend passes pre-computed params from Bitflow SDK
(define-public (invest-diversified
    ;; Total USDCx to invest
    (total-usdcx uint)
    (usdcx-token <ft-trait>)

    ;; === SWAP 1: STX (2-step: stableswap + xyk) ===
    ;; Step 1: USDCx -> aeUSDC (stableswap-core, v-1-2 trait)
    ;; Step 2: aeUSDC -> STX (xyk-swap-helper)
    (stx-amount uint)
    (stx-min-out uint)
    ;; Stableswap params (v-1-2 trait for stableswap-core)
    (stx-ss-token-x <ft-trait>)      ;; USDCx
    (stx-ss-token-y <ft-trait>)      ;; aeUSDC
    (stx-ss-pool <stableswap-pool-trait-v12>)
    ;; XYK params (using v1.2 tokens/pools per SDK)
    (stx-xyk-token-a <ft-trait>)     ;; token-stx-v-1-2
    (stx-xyk-token-b <ft-trait>)     ;; aeUSDC
    (stx-xyk-pool <xyk-pool-trait>)  ;; xyk-pool-stx-aeusdc-v-1-2
    (stx-output <ft-trait>)          ;; token-stx-v-1-2

    ;; === SWAP 2: sBTC (3-hop via multihop v1.2 swap-helper-b) ===
    ;; Route: USDCx -> aeUSDC (stableswap) -> STX (xyk) -> sBTC (xyk)
    ;; Note: multihop router uses v-1-4 stableswap trait
    (sbtc-amount uint)
    (sbtc-min-out uint)
    (sbtc-ss-token-a <ft-trait>)
    (sbtc-ss-token-b <ft-trait>)
    (sbtc-ss-pool <stableswap-pool-trait-v14>)
    (sbtc-xyk-token-a <ft-trait>)
    (sbtc-xyk-token-b <ft-trait>)
    (sbtc-xyk-token-c <ft-trait>)
    (sbtc-xyk-token-d <ft-trait>)
    (sbtc-xyk-pool-a <xyk-pool-trait>)
    (sbtc-xyk-pool-b <xyk-pool-trait>)
    (sbtc-output <ft-trait>)
  )
  (let
    (
      (investor tx-sender)
      (fee-amount (calculate-fee total-usdcx))
      (net-amount (- total-usdcx fee-amount))
    )
    ;; === VALIDATION ===
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (>= total-usdcx MIN-INVESTMENT) ERR-MIN-INVESTMENT)

    ;; === STEP 1: TRANSFER USDCX FROM USER ===
    (try! (contract-call? usdcx-token transfer total-usdcx investor (as-contract tx-sender) none))

    ;; === STEP 2: DEDUCT PLATFORM FEE ===
    (if (> fee-amount u0)
      (try! (as-contract (contract-call? usdcx-token transfer fee-amount tx-sender (var-get fee-recipient) none)))
      true
    )

    ;; === STEP 3: EXECUTE STX SWAP (2-step: stableswap + xyk) ===
    (if (> stx-amount u0)
      (let
        (
          ;; Step 1: Stableswap USDCx -> aeUSDC
          (ss-result (try! (as-contract (execute-stableswap
            stx-amount
            u1  ;; min-out for intermediate step (will check final)
            stx-ss-token-x
            stx-ss-token-y
            stx-ss-pool))))
          ;; Get aeUSDC balance after stableswap
          (aeusdc-balance (try! (contract-call? stx-ss-token-y get-balance (as-contract tx-sender))))
        )
        ;; Step 2: XYK aeUSDC -> STX
        (if (> aeusdc-balance u0)
          (let
            (
              (xyk-result (try! (as-contract (execute-xyk-swap
                aeusdc-balance
                stx-min-out
                stx-xyk-token-b  ;; aeUSDC (input)
                stx-xyk-token-a  ;; token-stx (output)
                stx-xyk-pool))))
              ;; Get STX balance after XYK swap
              (stx-balance (try! (contract-call? stx-output get-balance (as-contract tx-sender))))
            )
            ;; Transfer STX to investor
            (if (> stx-balance u0)
              (try! (as-contract (contract-call? stx-output transfer stx-balance tx-sender investor none)))
              true
            )
          )
          true
        )
      )
      true
    )

    ;; === STEP 4: EXECUTE sBTC SWAP (3-hop via multihop v1.2) ===
    (if (> sbtc-amount u0)
      (let
        (
          (swap-result (try! (as-contract (execute-swap-3hop
            sbtc-amount sbtc-min-out
            sbtc-ss-token-a sbtc-ss-token-b sbtc-ss-pool
            sbtc-xyk-token-a sbtc-xyk-token-b sbtc-xyk-token-c sbtc-xyk-token-d
            sbtc-xyk-pool-a sbtc-xyk-pool-b))))
          (balance (try! (contract-call? sbtc-output get-balance (as-contract tx-sender))))
        )
        (if (> balance u0)
          (try! (as-contract (contract-call? sbtc-output transfer balance tx-sender investor none)))
          true
        )
      )
      true
    )

    ;; === STEP 5: UPDATE STATS ===
    (var-set total-investments (+ (var-get total-investments) u1))
    (var-set total-volume (+ (var-get total-volume) total-usdcx))

    ;; === STEP 6: EMIT EVENT ===
    (print {
      event: "investment-complete-v18",
      investor: investor,
      total-usdcx: total-usdcx,
      net-amount: net-amount,
      fee-amount: fee-amount,
      stx-amount: stx-amount,
      sbtc-amount: sbtc-amount
    })

    (ok {
      invested: net-amount,
      fee: fee-amount
    })
  )
)

;; =====================
;; ADMIN FUNCTIONS
;; =====================

(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set contract-paused paused)
    (ok true)
  )
)

(define-public (set-platform-fee (fee-bp uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= fee-bp MAX-FEE) ERR-INVALID-AMOUNT)
    (var-set platform-fee-bp fee-bp)
    (ok true)
  )
)

(define-public (set-fee-recipient (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set fee-recipient recipient)
    (ok true)
  )
)

;; Emergency withdraw stuck tokens
(define-public (emergency-withdraw (token <ft-trait>) (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (as-contract (contract-call? token transfer amount tx-sender recipient none))
  )
)

;; =====================
;; END OF CONTRACT
;; =====================

```
