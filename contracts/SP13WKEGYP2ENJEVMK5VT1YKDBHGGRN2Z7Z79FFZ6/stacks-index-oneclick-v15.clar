;; =====================================================================
;; StacksIndex OneClick V15 - 2 Token Support (STX + sBTC)
;; =====================================================================
;;
;; V15: Simplified contract for 2 tokens only (STX and sBTC)
;; Learning from V9's trait pattern - traits as function parameters
;;
;; Routes:
;; - STX:  2-hop via router-stableswap-xyk-v-1-5 (swap-helper-a)
;;         USDCx -> aeUSDC (stableswap) -> STX (xyk)
;; - sBTC: 3-hop via router-stableswap-xyk-multihop-v-1-2 (swap-helper-b)
;;         USDCx -> aeUSDC (stableswap) -> STX (xyk) -> sBTC (xyk)
;;
;; =====================================================================

;; =====================
;; TRAITS
;; =====================

;; Bitflow SIP-010 trait
(use-trait ft-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)

;; Bitflow pool traits
(use-trait stableswap-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-4.stableswap-pool-trait)
;; Router v1.5 uses xyk-pool-trait v1.1
(use-trait xyk-pool-trait-v11 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-1.xyk-pool-trait)
;; Router multihop v1.2 uses xyk-pool-trait v1.2
(use-trait xyk-pool-trait-v12 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)

;; =====================
;; CONSTANTS
;; =====================

(define-constant CONTRACT-OWNER tx-sender)

;; Bitflow Routers
;; Router v1.5 for 2-hop (stableswap + 1 XYK) - used for STX
(define-constant BITFLOW-ROUTER-V15 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-v-1-5)
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

;; Execute 2-hop swap via router v1.5 (swap-helper-a)
;; Route: stableswap + 1 XYK hop
;; Used for: STX (USDCx -> aeUSDC -> STX)
(define-private (execute-swap-2hop
    (amount uint)
    (min-out uint)
    (ss-token-a <ft-trait>)
    (ss-token-b <ft-trait>)
    (ss-pool <stableswap-pool-trait>)
    (xyk-token-a <ft-trait>)
    (xyk-token-b <ft-trait>)
    (xyk-pool <xyk-pool-trait-v11>)
  )
  (contract-call? BITFLOW-ROUTER-V15 swap-helper-a
    amount
    min-out
    none       ;; provider
    false      ;; swaps-reversed
    { a: ss-token-a, b: ss-token-b }
    { a: ss-pool }
    { a: xyk-token-a, b: xyk-token-b }
    { a: xyk-pool }
  )
)

;; Execute 3-hop swap via router multihop v1.2 (swap-helper-b)
;; Route: stableswap + 2 XYK hops
;; Used for: sBTC (USDCx -> aeUSDC -> STX -> sBTC)
(define-private (execute-swap-3hop
    (amount uint)
    (min-out uint)
    (ss-token-a <ft-trait>)
    (ss-token-b <ft-trait>)
    (ss-pool <stableswap-pool-trait>)
    (xyk-token-a <ft-trait>)
    (xyk-token-b <ft-trait>)
    (xyk-token-c <ft-trait>)
    (xyk-token-d <ft-trait>)
    (xyk-pool-a <xyk-pool-trait-v12>)
    (xyk-pool-b <xyk-pool-trait-v12>)
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
;; - STX: 2-hop via router v1.5 (swap-helper-a)
;; - sBTC: 3-hop via router multihop v1.2 (swap-helper-b)
;;
;; Frontend passes pre-computed params from Bitflow API
(define-public (invest-diversified
    ;; Total USDCx to invest
    (total-usdcx uint)
    (usdcx-token <ft-trait>)

    ;; === SWAP 1: STX (2-hop via v1.5 swap-helper-a) ===
    ;; Route: USDCx -> aeUSDC (stableswap) -> STX (xyk)
    (stx-amount uint)
    (stx-min-out uint)
    (stx-ss-token-a <ft-trait>)
    (stx-ss-token-b <ft-trait>)
    (stx-ss-pool <stableswap-pool-trait>)
    (stx-xyk-token-a <ft-trait>)
    (stx-xyk-token-b <ft-trait>)
    (stx-xyk-pool <xyk-pool-trait-v11>)
    (stx-output <ft-trait>)

    ;; === SWAP 2: sBTC (3-hop via multihop v1.2 swap-helper-b) ===
    ;; Route: USDCx -> aeUSDC (stableswap) -> STX (xyk) -> sBTC (xyk)
    (sbtc-amount uint)
    (sbtc-min-out uint)
    (sbtc-ss-token-a <ft-trait>)
    (sbtc-ss-token-b <ft-trait>)
    (sbtc-ss-pool <stableswap-pool-trait>)
    (sbtc-xyk-token-a <ft-trait>)
    (sbtc-xyk-token-b <ft-trait>)
    (sbtc-xyk-token-c <ft-trait>)
    (sbtc-xyk-token-d <ft-trait>)
    (sbtc-xyk-pool-a <xyk-pool-trait-v12>)
    (sbtc-xyk-pool-b <xyk-pool-trait-v12>)
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

    ;; === STEP 3: EXECUTE STX SWAP (2-hop via v1.5) ===
    (if (> stx-amount u0)
      (let
        (
          (swap-result (try! (as-contract (execute-swap-2hop
            stx-amount stx-min-out
            stx-ss-token-a stx-ss-token-b stx-ss-pool
            stx-xyk-token-a stx-xyk-token-b stx-xyk-pool))))
          (balance (try! (contract-call? stx-output get-balance (as-contract tx-sender))))
        )
        (if (> balance u0)
          (try! (as-contract (contract-call? stx-output transfer balance tx-sender investor none)))
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
      event: "investment-complete-v15",
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
