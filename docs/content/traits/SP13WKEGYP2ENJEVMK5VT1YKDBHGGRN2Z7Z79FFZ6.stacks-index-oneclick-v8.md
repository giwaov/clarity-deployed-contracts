---
title: "Trait stacks-index-oneclick-v8"
draft: true
---
```
;; =====================================================================
;; StacksIndex OneClick V8 - 5 Token Support (Fixed WELSH Route)
;; =====================================================================
;;
;; Supports 5 index tokens via Bitflow XYK routers only:
;; - wSTX: 2-hop via router-v-1-2 (swap-helper-a)
;; - sBTC: 3-hop via router-v-1-2 (swap-helper-b)
;; - ALEX: 3-hop via router-v-1-2 (swap-helper-b)
;; - WELSH: 3-hop via router-v-1-2 (swap-helper-b) [FIXED from v7]
;; - DROID: 5-hop via router-v-1-2 swap-helper-c (stableswap + 3 xyk)
;;
;; V8 FIX: WELSH now uses 3-hop like sBTC/ALEX instead of broken 4-hop v1.5
;; Route: USDCx -> aeUSDC (stableswap) -> STX (xyk) -> WELSH (xyk)
;;
;; =====================================================================

;; =====================
;; TRAITS
;; =====================

(use-trait ft-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait stableswap-pool-trait-v14 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-4.stableswap-pool-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)

;; =====================
;; CONSTANTS
;; =====================

(define-constant CONTRACT-OWNER tx-sender)

;; Bitflow Router V1.2 (for all swaps)
(define-constant BITFLOW-ROUTER-V12 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2)

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
;; PRIVATE FUNCTIONS - Router V1.2
;; =====================

;; Execute 2-hop swap via router v1.2 (swap-helper-a)
;; Route: stableswap -> xyk
;; Used for: wSTX
(define-private (execute-swap-2hop-v12
    (amount uint)
    (min-out uint)
    (reversed bool)
    (ss-token-a <ft-trait>)
    (ss-token-b <ft-trait>)
    (ss-pool <stableswap-pool-trait-v14>)
    (xyk-token-a <ft-trait>)
    (xyk-token-b <ft-trait>)
    (xyk-pool-a <xyk-pool-trait>)
  )
  (contract-call? BITFLOW-ROUTER-V12 swap-helper-a
    amount
    min-out
    none
    reversed
    { a: ss-token-a, b: ss-token-b }
    { a: ss-pool }
    { a: xyk-token-a, b: xyk-token-b }
    { a: xyk-pool-a }
  )
)

;; Execute 3-hop swap via router v1.2 (swap-helper-b)
;; Route: stableswap -> xyk -> xyk
;; Used for: sBTC, ALEX, WELSH (V8 FIX: WELSH now uses this!)
(define-private (execute-swap-3hop-v12
    (amount uint)
    (min-out uint)
    (reversed bool)
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
  (contract-call? BITFLOW-ROUTER-V12 swap-helper-b
    amount
    min-out
    none
    reversed
    { a: ss-token-a, b: ss-token-b }
    { a: ss-pool }
    { a: xyk-token-a, b: xyk-token-b, c: xyk-token-c, d: xyk-token-d }
    { a: xyk-pool-a, b: xyk-pool-b }
  )
)

;; Execute 5-hop swap via router v1.2 (swap-helper-c)
;; Route: stableswap -> xyk -> xyk -> xyk
;; Used for: DROID
(define-private (execute-swap-5hop-v12
    (amount uint)
    (min-out uint)
    (reversed bool)
    (ss-token-a <ft-trait>)
    (ss-token-b <ft-trait>)
    (ss-pool <stableswap-pool-trait-v14>)
    (xyk-token-a <ft-trait>)
    (xyk-token-b <ft-trait>)
    (xyk-token-c <ft-trait>)
    (xyk-token-d <ft-trait>)
    (xyk-token-e <ft-trait>)
    (xyk-token-f <ft-trait>)
    (xyk-pool-a <xyk-pool-trait>)
    (xyk-pool-b <xyk-pool-trait>)
    (xyk-pool-c <xyk-pool-trait>)
  )
  (contract-call? BITFLOW-ROUTER-V12 swap-helper-c
    amount
    min-out
    none
    reversed
    { a: ss-token-a, b: ss-token-b }
    { a: ss-pool }
    { a: xyk-token-a, b: xyk-token-b, c: xyk-token-c, d: xyk-token-d, e: xyk-token-e, f: xyk-token-f }
    { a: xyk-pool-a, b: xyk-pool-b, c: xyk-pool-c }
  )
)

;; =====================
;; PUBLIC FUNCTIONS
;; =====================

;; Main investment function - 5 tokens supported:
;; - wSTX: 2-hop route via router v1.2
;; - sBTC: 3-hop route via router v1.2
;; - ALEX: 3-hop route via router v1.2
;; - WELSH: 3-hop route via router v1.2 (V8 FIX!)
;; - DROID: 5-hop route via router v1.2 swap-helper-c
;;
;; Frontend passes pre-computed params from Bitflow SDK
(define-public (invest-diversified
    ;; Total USDCx to invest
    (total-usdcx uint)
    (usdcx-token <ft-trait>)

    ;; === SWAP 1: wSTX (2-hop via v1.2) ===
    (wstx-amount uint)
    (wstx-min-out uint)
    (wstx-reversed bool)
    (wstx-ss-token-a <ft-trait>)
    (wstx-ss-token-b <ft-trait>)
    (wstx-ss-pool <stableswap-pool-trait-v14>)
    (wstx-xyk-token-a <ft-trait>)
    (wstx-xyk-token-b <ft-trait>)
    (wstx-xyk-pool <xyk-pool-trait>)
    (wstx-output <ft-trait>)

    ;; === SWAP 2: sBTC (3-hop via v1.2) ===
    (sbtc-amount uint)
    (sbtc-min-out uint)
    (sbtc-reversed bool)
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

    ;; === SWAP 3: ALEX (3-hop via v1.2) ===
    (alex-amount uint)
    (alex-min-out uint)
    (alex-reversed bool)
    (alex-ss-token-a <ft-trait>)
    (alex-ss-token-b <ft-trait>)
    (alex-ss-pool <stableswap-pool-trait-v14>)
    (alex-xyk-token-a <ft-trait>)
    (alex-xyk-token-b <ft-trait>)
    (alex-xyk-token-c <ft-trait>)
    (alex-xyk-token-d <ft-trait>)
    (alex-xyk-pool-a <xyk-pool-trait>)
    (alex-xyk-pool-b <xyk-pool-trait>)
    (alex-output <ft-trait>)

    ;; === SWAP 4: WELSH (3-hop via v1.2) - V8 FIX! ===
    ;; Route: USDCx -> aeUSDC (ss) -> STX (xyk) -> WELSH (xyk)
    (welsh-amount uint)
    (welsh-min-out uint)
    (welsh-reversed bool)
    (welsh-ss-token-a <ft-trait>)
    (welsh-ss-token-b <ft-trait>)
    (welsh-ss-pool <stableswap-pool-trait-v14>)
    (welsh-xyk-token-a <ft-trait>)
    (welsh-xyk-token-b <ft-trait>)
    (welsh-xyk-token-c <ft-trait>)
    (welsh-xyk-token-d <ft-trait>)
    (welsh-xyk-pool-a <xyk-pool-trait>)
    (welsh-xyk-pool-b <xyk-pool-trait>)
    (welsh-output <ft-trait>)

    ;; === SWAP 5: DROID (5-hop via v1.2 swap-helper-c) ===
    (droid-amount uint)
    (droid-min-out uint)
    (droid-reversed bool)
    (droid-ss-token-a <ft-trait>)
    (droid-ss-token-b <ft-trait>)
    (droid-ss-pool <stableswap-pool-trait-v14>)
    (droid-xyk-token-a <ft-trait>)
    (droid-xyk-token-b <ft-trait>)
    (droid-xyk-token-c <ft-trait>)
    (droid-xyk-token-d <ft-trait>)
    (droid-xyk-token-e <ft-trait>)
    (droid-xyk-token-f <ft-trait>)
    (droid-xyk-pool-a <xyk-pool-trait>)
    (droid-xyk-pool-b <xyk-pool-trait>)
    (droid-xyk-pool-c <xyk-pool-trait>)
    (droid-output <ft-trait>)
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

    ;; === STEP 3: EXECUTE SWAPS ===

    ;; Swap 1: wSTX (2-hop via v1.2)
    (if (> wstx-amount u0)
      (let
        (
          (swap-result (try! (as-contract (execute-swap-2hop-v12
            wstx-amount wstx-min-out wstx-reversed
            wstx-ss-token-a wstx-ss-token-b wstx-ss-pool
            wstx-xyk-token-a wstx-xyk-token-b wstx-xyk-pool))))
          (balance (try! (contract-call? wstx-output get-balance (as-contract tx-sender))))
        )
        (if (> balance u0)
          (try! (as-contract (contract-call? wstx-output transfer balance tx-sender investor none)))
          true
        )
      )
      true
    )

    ;; Swap 2: sBTC (3-hop via v1.2)
    (if (> sbtc-amount u0)
      (let
        (
          (swap-result (try! (as-contract (execute-swap-3hop-v12
            sbtc-amount sbtc-min-out sbtc-reversed
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

    ;; Swap 3: ALEX (3-hop via v1.2)
    (if (> alex-amount u0)
      (let
        (
          (swap-result (try! (as-contract (execute-swap-3hop-v12
            alex-amount alex-min-out alex-reversed
            alex-ss-token-a alex-ss-token-b alex-ss-pool
            alex-xyk-token-a alex-xyk-token-b alex-xyk-token-c alex-xyk-token-d
            alex-xyk-pool-a alex-xyk-pool-b))))
          (balance (try! (contract-call? alex-output get-balance (as-contract tx-sender))))
        )
        (if (> balance u0)
          (try! (as-contract (contract-call? alex-output transfer balance tx-sender investor none)))
          true
        )
      )
      true
    )

    ;; Swap 4: WELSH (3-hop via v1.2) - V8 FIX!
    ;; Route: USDCx -> aeUSDC (ss) -> STX (xyk) -> WELSH (xyk)
    (if (> welsh-amount u0)
      (let
        (
          (swap-result (try! (as-contract (execute-swap-3hop-v12
            welsh-amount welsh-min-out welsh-reversed
            welsh-ss-token-a welsh-ss-token-b welsh-ss-pool
            welsh-xyk-token-a welsh-xyk-token-b welsh-xyk-token-c welsh-xyk-token-d
            welsh-xyk-pool-a welsh-xyk-pool-b))))
          (balance (try! (contract-call? welsh-output get-balance (as-contract tx-sender))))
        )
        (if (> balance u0)
          (try! (as-contract (contract-call? welsh-output transfer balance tx-sender investor none)))
          true
        )
      )
      true
    )

    ;; Swap 5: DROID (5-hop via v1.2 swap-helper-c)
    (if (> droid-amount u0)
      (let
        (
          (swap-result (try! (as-contract (execute-swap-5hop-v12
            droid-amount droid-min-out droid-reversed
            droid-ss-token-a droid-ss-token-b droid-ss-pool
            droid-xyk-token-a droid-xyk-token-b droid-xyk-token-c droid-xyk-token-d
            droid-xyk-token-e droid-xyk-token-f
            droid-xyk-pool-a droid-xyk-pool-b droid-xyk-pool-c))))
          (balance (try! (contract-call? droid-output get-balance (as-contract tx-sender))))
        )
        (if (> balance u0)
          (try! (as-contract (contract-call? droid-output transfer balance tx-sender investor none)))
          true
        )
      )
      true
    )

    ;; === STEP 4: UPDATE STATS ===
    (var-set total-investments (+ (var-get total-investments) u1))
    (var-set total-volume (+ (var-get total-volume) total-usdcx))

    ;; === STEP 5: EMIT EVENT ===
    (print {
      event: "investment-complete-v8",
      investor: investor,
      total-usdcx: total-usdcx,
      net-amount: net-amount,
      fee-amount: fee-amount,
      wstx-amount: wstx-amount,
      sbtc-amount: sbtc-amount,
      alex-amount: alex-amount,
      welsh-amount: welsh-amount,
      droid-amount: droid-amount
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
