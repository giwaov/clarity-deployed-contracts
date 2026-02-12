---
title: "Trait stacks-index-oneclick-1"
draft: true
---
```
;; =====================================================================
;; StacksIndex - 1-Click Diversified Investment Contract
;; =====================================================================
;;
;; PURPOSE:
;; Enables users to invest USDCx into a diversified basket of Stacks
;; ecosystem tokens with a single transaction. The contract handles:
;; 1. Accepting USDCx deposits
;; 2. Splitting funds according to allocation strategy
;; 3. Executing swaps via Bitflow DEX (multihop router)
;; 4. Sending acquired tokens to investor's wallet
;;
;; ARCHITECTURE:
;; - Uses Bitflow's router-stableswap-xyk-multihop-v-1-2 for optimal routing
;; - Swap parameters are prepared off-chain via BitflowSDK
;; - Supports 3 preset strategies + custom allocations
;; - Each token swap is executed separately with SDK-provided routing
;; - Tokens are sent directly to user (no custodial holding)
;;
;; SUPPORTED TOKENS:
;; - sBTC (Bitcoin on Stacks)
;; - wSTX (Wrapped STX)
;; - ALEX (Alex governance token)
;; - WELSH (Welsh Corgi memecoin)
;; - LEO (Leo token)
;;
;; SECURITY FEATURES:
;; - tx-sender validation on all admin functions
;; - Slippage protection with configurable tolerance
;; - Platform fee capped at 1%
;; - Emergency withdrawal for stuck funds
;; - Pausable contract state
;;
;; =====================================================================

;; =====================
;; TRAITS
;; =====================

;; Use Bitflow's SIP-010 trait for compatibility with their router
(use-trait ft-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait stableswap-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-4.stableswap-pool-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)

;; =====================
;; CONSTANTS - ERROR CODES
;; =====================

(define-constant CONTRACT-OWNER tx-sender)

;; Error codes using u100X pattern for easy identification
(define-constant ERR-NOT-AUTHORIZED (err u1001))
(define-constant ERR-INVALID-AMOUNT (err u1002))
(define-constant ERR-INVALID-ALLOCATION (err u1003))
(define-constant ERR-SWAP-FAILED (err u1004))
(define-constant ERR-TRANSFER-FAILED (err u1005))
(define-constant ERR-SLIPPAGE-EXCEEDED (err u1006))
(define-constant ERR-CONTRACT-PAUSED (err u1007))
(define-constant ERR-INVALID-STRATEGY (err u1008))
(define-constant ERR-INSUFFICIENT-BALANCE (err u1009))
(define-constant ERR-MIN-INVESTMENT (err u1010))
(define-constant ERR-INVESTMENT-NOT-FOUND (err u1011))
(define-constant ERR-ALREADY-PROCESSED (err u1012))

;; =====================
;; CONSTANTS - STRATEGY IDS
;; =====================

(define-constant STRATEGY-CONSERVATIVE u1)  ;; Heavy sBTC/STX (safer assets)
(define-constant STRATEGY-BALANCED u2)      ;; Mixed portfolio
(define-constant STRATEGY-AGGRESSIVE u3)    ;; More memecoins (higher risk/reward)

;; =====================
;; CONSTANTS - TOKEN CONTRACTS (Mainnet)
;; =====================

;; Input token - USDC bridged via Allbridge
(define-constant USDCX-CONTRACT 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx-v1)

;; Output tokens
(define-constant SBTC-CONTRACT 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token)
(define-constant WSTX-CONTRACT 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx)
(define-constant ALEX-CONTRACT 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex)
(define-constant WELSH-CONTRACT 'SP3NE50GEXFG9SZGTT51P40X2CKYSZ5CC4ZTZ7A2G.welshcorgicoin-token)
(define-constant LEO-CONTRACT 'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token)

;; =====================
;; CONSTANTS - DEX CONTRACTS (Bitflow Mainnet)
;; =====================

;; Bitflow multihop router - handles stableswap + XYK routing
(define-constant BITFLOW-ROUTER 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2)

;; =====================
;; CONSTANTS - CONFIGURATION
;; =====================

;; Basis points denominator (100% = 10000)
(define-constant BP-DENOMINATOR u10000)

;; Minimum investment (1 USDCx with 6 decimals = 1000000)
(define-constant MIN-INVESTMENT u1000000)

;; Default slippage tolerance (0.5% = 50bp)
(define-constant DEFAULT-SLIPPAGE u50)

;; Maximum slippage allowed (5% = 500bp)
(define-constant MAX-SLIPPAGE u500)

;; Maximum platform fee (1% = 100bp)
(define-constant MAX-FEE u100)

;; =====================
;; DATA VARIABLES
;; =====================

;; Contract state
(define-data-var contract-paused bool false)
(define-data-var global-slippage uint DEFAULT-SLIPPAGE)

;; Statistics tracking
(define-data-var total-investments uint u0)
(define-data-var total-usdcx-volume uint u0)
(define-data-var total-unique-investors uint u0)

;; Fee configuration (optional platform fee)
(define-data-var platform-fee-bp uint u0)  ;; 0 = no fee
(define-data-var fee-recipient principal CONTRACT-OWNER)

;; Investment ID counter
(define-data-var next-investment-id uint u1)

;; =====================
;; DATA MAPS
;; =====================

;; Allocation type: 5 tokens each with basis points
(define-map strategy-allocations
  uint
  { sbtc: uint, wstx: uint, alex: uint, welsh: uint, leo: uint }
)

;; Custom user allocations
(define-map user-allocations
  principal
  { sbtc: uint, wstx: uint, alex: uint, welsh: uint, leo: uint }
)

;; User preferred strategy
(define-map user-preferred-strategy principal uint)

;; Investment records for history/tracking
(define-map investments
  uint
  {
    investor: principal,
    usdcx-amount: uint,
    net-amount: uint,
    fee-amount: uint,
    strategy: uint,
    allocations: { sbtc: uint, wstx: uint, alex: uint, welsh: uint, leo: uint },
    amounts-per-token: { sbtc: uint, wstx: uint, alex: uint, welsh: uint, leo: uint },
    block-height: uint,
    status: (string-ascii 16)
  }
)

;; Track unique investors
(define-map has-invested principal bool)

;; User statistics
(define-map user-investment-count principal uint)
(define-map user-total-invested principal uint)

;; =====================
;; INITIALIZATION
;; =====================

;; Conservative: 45% sBTC, 35% wSTX, 20% ALEX (no memes)
(map-set strategy-allocations STRATEGY-CONSERVATIVE
  { sbtc: u4500, wstx: u3500, alex: u2000, welsh: u0, leo: u0 }
)

;; Balanced: 25% sBTC, 25% wSTX, 20% ALEX, 15% WELSH, 15% LEO
(map-set strategy-allocations STRATEGY-BALANCED
  { sbtc: u2500, wstx: u2500, alex: u2000, welsh: u1500, leo: u1500 }
)

;; Aggressive: 15% sBTC, 15% wSTX, 20% ALEX, 25% WELSH, 25% LEO
(map-set strategy-allocations STRATEGY-AGGRESSIVE
  { sbtc: u1500, wstx: u1500, alex: u2000, welsh: u2500, leo: u2500 }
)

;; =====================
;; READ-ONLY FUNCTIONS
;; =====================

;; Get contract statistics
(define-read-only (get-contract-stats)
  {
    total-investments: (var-get total-investments),
    total-usdcx-volume: (var-get total-usdcx-volume),
    total-unique-investors: (var-get total-unique-investors),
    is-paused: (var-get contract-paused),
    platform-fee-bp: (var-get platform-fee-bp),
    global-slippage: (var-get global-slippage),
    next-investment-id: (var-get next-investment-id)
  }
)

;; Get specific strategy allocation
(define-read-only (get-strategy-allocation (strategy-id uint))
  (map-get? strategy-allocations strategy-id)
)

;; Get all preset strategies
(define-read-only (get-all-strategies)
  {
    conservative: (unwrap-panic (map-get? strategy-allocations STRATEGY-CONSERVATIVE)),
    balanced: (unwrap-panic (map-get? strategy-allocations STRATEGY-BALANCED)),
    aggressive: (unwrap-panic (map-get? strategy-allocations STRATEGY-AGGRESSIVE))
  }
)

;; Get user's custom allocation
(define-read-only (get-user-allocation (user principal))
  (map-get? user-allocations user)
)

;; Get effective allocation for user
(define-read-only (get-effective-allocation (user principal) (strategy-id uint))
  (match (map-get? user-allocations user)
    custom-alloc custom-alloc
    (default-to
      { sbtc: u2500, wstx: u2500, alex: u2000, welsh: u1500, leo: u1500 }
      (map-get? strategy-allocations strategy-id)
    )
  )
)

;; Calculate investment breakdown
(define-read-only (calculate-investment-breakdown
    (usdcx-amount uint)
    (allocations { sbtc: uint, wstx: uint, alex: uint, welsh: uint, leo: uint })
  )
  (let
    (
      (fee-amount (/ (* usdcx-amount (var-get platform-fee-bp)) BP-DENOMINATOR))
      (net-amount (- usdcx-amount fee-amount))
    )
    {
      gross-amount: usdcx-amount,
      fee-amount: fee-amount,
      net-amount: net-amount,
      sbtc-usdcx: (/ (* net-amount (get sbtc allocations)) BP-DENOMINATOR),
      wstx-usdcx: (/ (* net-amount (get wstx allocations)) BP-DENOMINATOR),
      alex-usdcx: (/ (* net-amount (get alex allocations)) BP-DENOMINATOR),
      welsh-usdcx: (/ (* net-amount (get welsh allocations)) BP-DENOMINATOR),
      leo-usdcx: (/ (* net-amount (get leo allocations)) BP-DENOMINATOR)
    }
  )
)

;; Validate allocation sums to 10000bp (100%)
(define-read-only (is-valid-allocation
    (allocations { sbtc: uint, wstx: uint, alex: uint, welsh: uint, leo: uint })
  )
  (is-eq BP-DENOMINATOR
    (+ (get sbtc allocations)
       (+ (get wstx allocations)
          (+ (get alex allocations)
             (+ (get welsh allocations)
                (get leo allocations)))))
  )
)

;; Get investment by ID
(define-read-only (get-investment (investment-id uint))
  (map-get? investments investment-id)
)

;; Get user statistics
(define-read-only (get-user-stats (user principal))
  {
    investment-count: (default-to u0 (map-get? user-investment-count user)),
    total-invested: (default-to u0 (map-get? user-total-invested user)),
    has-custom-allocation: (is-some (map-get? user-allocations user)),
    preferred-strategy: (default-to STRATEGY-BALANCED (map-get? user-preferred-strategy user))
  }
)

;; Calculate minimum output with slippage
(define-read-only (calculate-min-output (expected-amount uint) (slippage-bp uint))
  (- expected-amount (/ (* expected-amount slippage-bp) BP-DENOMINATOR))
)

;; Preview investment before execution
(define-read-only (preview-investment (usdcx-amount uint) (strategy-id uint) (user principal))
  (let
    (
      (allocations (get-effective-allocation user strategy-id))
      (breakdown (calculate-investment-breakdown usdcx-amount allocations))
    )
    {
      valid: (and
        (>= usdcx-amount MIN-INVESTMENT)
        (not (var-get contract-paused))
        (and (>= strategy-id u1) (<= strategy-id u3))
      ),
      strategy: strategy-id,
      allocations: allocations,
      breakdown: breakdown,
      min-investment: MIN-INVESTMENT,
      platform-fee-bp: (var-get platform-fee-bp),
      slippage-bp: (var-get global-slippage)
    }
  )
)

;; =====================
;; PRIVATE FUNCTIONS
;; =====================

;; Record investment in history and update stats
(define-private (record-investment
    (investor principal)
    (usdcx-amount uint)
    (net-amount uint)
    (fee-amount uint)
    (strategy uint)
    (allocations { sbtc: uint, wstx: uint, alex: uint, welsh: uint, leo: uint })
    (amounts { sbtc: uint, wstx: uint, alex: uint, welsh: uint, leo: uint })
  )
  (let
    (
      (investment-id (var-get next-investment-id))
      (user-count (default-to u0 (map-get? user-investment-count investor)))
      (user-total (default-to u0 (map-get? user-total-invested investor)))
    )
    ;; Store investment record
    (map-set investments investment-id {
      investor: investor,
      usdcx-amount: usdcx-amount,
      net-amount: net-amount,
      fee-amount: fee-amount,
      strategy: strategy,
      allocations: allocations,
      amounts-per-token: amounts,
      block-height: stacks-block-height,
      status: "completed"
    })

    ;; Update user stats
    (map-set user-investment-count investor (+ user-count u1))
    (map-set user-total-invested investor (+ user-total usdcx-amount))

    ;; Update global stats
    (var-set next-investment-id (+ investment-id u1))
    (var-set total-investments (+ (var-get total-investments) u1))
    (var-set total-usdcx-volume (+ (var-get total-usdcx-volume) usdcx-amount))

    ;; Track unique investors
    (if (is-none (map-get? has-invested investor))
      (begin
        (map-set has-invested investor true)
        (var-set total-unique-investors (+ (var-get total-unique-investors) u1))
      )
      true
    )

    investment-id
  )
)

;; =====================
;; PUBLIC FUNCTIONS - SINGLE TOKEN SWAP
;; =====================

;; Execute a single swap using Bitflow's multihop router (swap-helper-a variant)
;; This is the simplest routing: 1 stableswap hop + 1 xyk hop
;; Parameters are prepared by BitflowSDK off-chain
(define-public (execute-swap-a
    (amount uint)
    (min-received uint)
    (swaps-reversed bool)
    (stableswap-token-a <ft-trait>)
    (stableswap-token-b <ft-trait>)
    (stableswap-pool-a <stableswap-pool-trait>)
    (xyk-token-a <ft-trait>)
    (xyk-token-b <ft-trait>)
    (xyk-pool-a <xyk-pool-trait>)
  )
  (begin
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)

    (as-contract
      (contract-call? BITFLOW-ROUTER swap-helper-a
        amount
        min-received
        none  ;; provider (none for no aggregator fee)
        swaps-reversed
        { a: stableswap-token-a, b: stableswap-token-b }
        { a: stableswap-pool-a }
        { a: xyk-token-a, b: xyk-token-b }
        { a: xyk-pool-a }
      )
    )
  )
)

;; Execute swap using swap-helper-b (1 stableswap + 2 xyk hops)
(define-public (execute-swap-b
    (amount uint)
    (min-received uint)
    (swaps-reversed bool)
    (stableswap-token-a <ft-trait>)
    (stableswap-token-b <ft-trait>)
    (stableswap-pool-a <stableswap-pool-trait>)
    (xyk-token-a <ft-trait>)
    (xyk-token-b <ft-trait>)
    (xyk-token-c <ft-trait>)
    (xyk-token-d <ft-trait>)
    (xyk-pool-a <xyk-pool-trait>)
    (xyk-pool-b <xyk-pool-trait>)
  )
  (begin
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)

    (as-contract
      (contract-call? BITFLOW-ROUTER swap-helper-b
        amount
        min-received
        none
        swaps-reversed
        { a: stableswap-token-a, b: stableswap-token-b }
        { a: stableswap-pool-a }
        { a: xyk-token-a, b: xyk-token-b, c: xyk-token-c, d: xyk-token-d }
        { a: xyk-pool-a, b: xyk-pool-b }
      )
    )
  )
)

;; =====================
;; PUBLIC FUNCTIONS - DIVERSIFIED INVESTMENT
;; =====================

;; Main investment function - simplified version
;; User deposits USDCx, contract tracks allocation, user executes swaps separately
;; This approach allows the frontend to use BitflowSDK for optimal routing
(define-public (deposit-for-investment
    (usdcx-amount uint)
    (strategy-id uint)
    (usdcx-token <ft-trait>)
  )
  (let
    (
      (investor tx-sender)
      (allocations (get-effective-allocation investor strategy-id))
      (breakdown (calculate-investment-breakdown usdcx-amount allocations))
    )

    ;; === VALIDATION ===
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (>= usdcx-amount MIN-INVESTMENT) ERR-MIN-INVESTMENT)
    (asserts! (and (>= strategy-id u1) (<= strategy-id u3)) ERR-INVALID-STRATEGY)

    ;; === STEP 1: TRANSFER USDCX FROM INVESTOR ===
    (try! (contract-call? usdcx-token transfer
      usdcx-amount
      investor
      (as-contract tx-sender)
      none))

    ;; === STEP 2: DEDUCT PLATFORM FEE (IF ANY) ===
    (if (> (get fee-amount breakdown) u0)
      (try! (as-contract (contract-call? usdcx-token transfer
        (get fee-amount breakdown)
        tx-sender
        (var-get fee-recipient)
        none)))
      true
    )

    ;; === STEP 3: RECORD INVESTMENT ===
    (let
      (
        (sbtc-amount (get sbtc-usdcx breakdown))
        (wstx-amount (get wstx-usdcx breakdown))
        (alex-amount (get alex-usdcx breakdown))
        (welsh-amount (get welsh-usdcx breakdown))
        (leo-amount (get leo-usdcx breakdown))
        (investment-id (record-investment
          investor
          usdcx-amount
          (get net-amount breakdown)
          (get fee-amount breakdown)
          strategy-id
          allocations
          { sbtc: sbtc-amount, wstx: wstx-amount, alex: alex-amount, welsh: welsh-amount, leo: leo-amount }
        ))
      )

      ;; Emit event for frontend to execute swaps
      (print {
        event: "investment-deposited",
        investment-id: investment-id,
        investor: investor,
        usdcx-amount: usdcx-amount,
        net-amount: (get net-amount breakdown),
        fee-amount: (get fee-amount breakdown),
        strategy: strategy-id,
        allocations: allocations,
        amounts-to-swap: {
          sbtc: sbtc-amount,
          wstx: wstx-amount,
          alex: alex-amount,
          welsh: welsh-amount,
          leo: leo-amount
        },
        block-height: stacks-block-height
      })

      (ok {
        investment-id: investment-id,
        net-invested: (get net-amount breakdown),
        amounts-to-swap: {
          sbtc: sbtc-amount,
          wstx: wstx-amount,
          alex: alex-amount,
          welsh: welsh-amount,
          leo: leo-amount
        }
      })
    )
  )
)

;; Execute swap and forward tokens to investor
;; Called by frontend after deposit, using BitflowSDK-prepared params
(define-public (execute-swap-and-forward-a
    (investment-id uint)
    (token-type (string-ascii 5))  ;; "sbtc", "wstx", "alex", "welsh", "leo"
    (amount uint)
    (min-received uint)
    (swaps-reversed bool)
    (stableswap-token-a <ft-trait>)
    (stableswap-token-b <ft-trait>)
    (stableswap-pool-a <stableswap-pool-trait>)
    (xyk-token-a <ft-trait>)
    (xyk-token-b <ft-trait>)
    (xyk-pool-a <xyk-pool-trait>)
    (output-token <ft-trait>)
  )
  (let
    (
      (investment (unwrap! (map-get? investments investment-id) ERR-INVESTMENT-NOT-FOUND))
      (investor (get investor investment))
    )
    ;; Verify caller is the original investor
    (asserts! (is-eq tx-sender investor) ERR-NOT-AUTHORIZED)
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)

    ;; Execute swap via Bitflow router
    (let
      (
        (swap-result (try! (as-contract
          (contract-call? BITFLOW-ROUTER swap-helper-a
            amount
            min-received
            none
            swaps-reversed
            { a: stableswap-token-a, b: stableswap-token-b }
            { a: stableswap-pool-a }
            { a: xyk-token-a, b: xyk-token-b }
            { a: xyk-pool-a }
          ))))
      )
      ;; Forward received tokens to investor
      (let
        (
          (token-balance (try! (contract-call? output-token get-balance (as-contract tx-sender))))
        )
        (if (> token-balance u0)
          (try! (as-contract (contract-call? output-token transfer token-balance tx-sender investor none)))
          true
        )

        (print {
          event: "swap-executed",
          investment-id: investment-id,
          token-type: token-type,
          amount-in: amount,
          amount-out: swap-result,
          investor: investor
        })

        (ok swap-result)
      )
    )
  )
)

;; Simplified version: withdraw USDCx back if user doesn't want to proceed with swaps
(define-public (withdraw-unswapped-funds
    (investment-id uint)
    (usdcx-token <ft-trait>)
  )
  (let
    (
      (investment (unwrap! (map-get? investments investment-id) ERR-INVESTMENT-NOT-FOUND))
      (investor (get investor investment))
    )
    ;; Only original investor can withdraw
    (asserts! (is-eq tx-sender investor) ERR-NOT-AUTHORIZED)

    ;; Get contract's USDCx balance
    (let
      (
        (usdcx-balance (try! (contract-call? usdcx-token get-balance (as-contract tx-sender))))
      )
      (if (> usdcx-balance u0)
        (begin
          (try! (as-contract (contract-call? usdcx-token transfer usdcx-balance tx-sender investor none)))
          (print {
            event: "funds-withdrawn",
            investment-id: investment-id,
            investor: investor,
            amount: usdcx-balance
          })
          (ok usdcx-balance)
        )
        ERR-INSUFFICIENT-BALANCE
      )
    )
  )
)

;; =====================
;; PUBLIC FUNCTIONS - USER SETTINGS
;; =====================

;; Set custom allocation percentages
(define-public (set-custom-allocation
    (allocations { sbtc: uint, wstx: uint, alex: uint, welsh: uint, leo: uint })
  )
  (begin
    ;; Validate allocation sums to 100%
    (asserts! (is-valid-allocation allocations) ERR-INVALID-ALLOCATION)

    ;; Save user allocation
    (map-set user-allocations tx-sender allocations)

    (print {
      event: "custom-allocation-set",
      user: tx-sender,
      allocations: allocations
    })

    (ok true)
  )
)

;; Clear custom allocation
(define-public (clear-custom-allocation)
  (begin
    (map-delete user-allocations tx-sender)
    (print { event: "custom-allocation-cleared", user: tx-sender })
    (ok true)
  )
)

;; Set preferred default strategy
(define-public (set-preferred-strategy (strategy-id uint))
  (begin
    (asserts! (and (>= strategy-id u1) (<= strategy-id u3)) ERR-INVALID-STRATEGY)
    (map-set user-preferred-strategy tx-sender strategy-id)
    (ok true)
  )
)

;; =====================
;; ADMIN FUNCTIONS
;; =====================

;; Pause/unpause contract
(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set contract-paused paused)
    (print { event: "contract-pause-changed", paused: paused })
    (ok true)
  )
)

;; Update global slippage tolerance
(define-public (set-global-slippage (slippage-bp uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= slippage-bp MAX-SLIPPAGE) ERR-SLIPPAGE-EXCEEDED)
    (var-set global-slippage slippage-bp)
    (ok true)
  )
)

;; Update platform fee (max 1%)
(define-public (set-platform-fee (fee-bp uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= fee-bp MAX-FEE) ERR-INVALID-AMOUNT)
    (var-set platform-fee-bp fee-bp)
    (print { event: "platform-fee-updated", fee-bp: fee-bp })
    (ok true)
  )
)

;; Update fee recipient
(define-public (set-fee-recipient (new-recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set fee-recipient new-recipient)
    (ok true)
  )
)

;; Update strategy allocation (admin only)
(define-public (update-strategy-allocation
    (strategy-id uint)
    (allocations { sbtc: uint, wstx: uint, alex: uint, welsh: uint, leo: uint })
  )
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= strategy-id u1) (<= strategy-id u3)) ERR-INVALID-STRATEGY)
    (asserts! (is-valid-allocation allocations) ERR-INVALID-ALLOCATION)

    (map-set strategy-allocations strategy-id allocations)

    (print {
      event: "strategy-updated",
      strategy-id: strategy-id,
      allocations: allocations
    })

    (ok true)
  )
)

;; Emergency withdraw stuck tokens (admin only)
(define-public (emergency-withdraw (token-contract <ft-trait>) (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (as-contract (contract-call? token-contract transfer amount tx-sender recipient none))
  )
)

;; =====================
;; END OF CONTRACT
;; =====================

```
