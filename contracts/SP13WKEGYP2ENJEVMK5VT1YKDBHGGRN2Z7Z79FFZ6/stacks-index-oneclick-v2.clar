;; =====================================================================
;; StacksIndex OneClick V2 - Single Transaction Diversified Investment
;; =====================================================================
;;
;; User deposits USDCx and receives multiple tokens in ONE transaction.
;; Frontend prepares all swap parameters using Bitflow SDK.
;;
;; Flow:
;; 1. Frontend gets quotes from Bitflow SDK for each token
;; 2. Frontend builds transaction with all swap params
;; 3. User signs ONE transaction
;; 4. Contract executes all swaps atomically
;; 5. Tokens sent directly to user's wallet
;;
;; =====================================================================

;; =====================
;; TRAITS
;; =====================

(use-trait ft-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait stableswap-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-4.stableswap-pool-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)

;; =====================
;; CONSTANTS
;; =====================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant BITFLOW-ROUTER 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2)

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

;; Execute a single swap via Bitflow router (swap-helper-a: 1 stableswap + 1 xyk)
(define-private (execute-swap-a
    (amount uint)
    (min-out uint)
    (reversed bool)
    (ss-token-a <ft-trait>)
    (ss-token-b <ft-trait>)
    (ss-pool <stableswap-pool-trait>)
    (xyk-token-a <ft-trait>)
    (xyk-token-b <ft-trait>)
    (xyk-pool <xyk-pool-trait>)
  )
  (contract-call? BITFLOW-ROUTER swap-helper-a
    amount
    min-out
    none
    reversed
    { a: ss-token-a, b: ss-token-b }
    { a: ss-pool }
    { a: xyk-token-a, b: xyk-token-b }
    { a: xyk-pool }
  )
)

;; =====================
;; PUBLIC FUNCTIONS
;; =====================

;; Main investment function - executes up to 5 swaps in ONE transaction
;; Frontend passes pre-computed params from Bitflow SDK
;;
;; For tokens not being purchased, pass amount u0
(define-public (invest-diversified
    ;; Total USDCx to invest
    (total-usdcx uint)
    ;; USDCx token trait
    (usdcx-token <ft-trait>)

    ;; === SWAP 1: sBTC ===
    (sbtc-usdcx-amount uint)
    (sbtc-min-out uint)
    (sbtc-reversed bool)
    (sbtc-ss-token-a <ft-trait>)
    (sbtc-ss-token-b <ft-trait>)
    (sbtc-ss-pool <stableswap-pool-trait>)
    (sbtc-xyk-token-a <ft-trait>)
    (sbtc-xyk-token-b <ft-trait>)
    (sbtc-xyk-pool <xyk-pool-trait>)
    (sbtc-output <ft-trait>)

    ;; === SWAP 2: wSTX ===
    (wstx-usdcx-amount uint)
    (wstx-min-out uint)
    (wstx-reversed bool)
    (wstx-ss-token-a <ft-trait>)
    (wstx-ss-token-b <ft-trait>)
    (wstx-ss-pool <stableswap-pool-trait>)
    (wstx-xyk-token-a <ft-trait>)
    (wstx-xyk-token-b <ft-trait>)
    (wstx-xyk-pool <xyk-pool-trait>)
    (wstx-output <ft-trait>)

    ;; === SWAP 3: ALEX ===
    (alex-usdcx-amount uint)
    (alex-min-out uint)
    (alex-reversed bool)
    (alex-ss-token-a <ft-trait>)
    (alex-ss-token-b <ft-trait>)
    (alex-ss-pool <stableswap-pool-trait>)
    (alex-xyk-token-a <ft-trait>)
    (alex-xyk-token-b <ft-trait>)
    (alex-xyk-pool <xyk-pool-trait>)
    (alex-output <ft-trait>)

    ;; === SWAP 4: WELSH ===
    (welsh-usdcx-amount uint)
    (welsh-min-out uint)
    (welsh-reversed bool)
    (welsh-ss-token-a <ft-trait>)
    (welsh-ss-token-b <ft-trait>)
    (welsh-ss-pool <stableswap-pool-trait>)
    (welsh-xyk-token-a <ft-trait>)
    (welsh-xyk-token-b <ft-trait>)
    (welsh-xyk-pool <xyk-pool-trait>)
    (welsh-output <ft-trait>)

    ;; === SWAP 5: LEO ===
    (leo-usdcx-amount uint)
    (leo-min-out uint)
    (leo-reversed bool)
    (leo-ss-token-a <ft-trait>)
    (leo-ss-token-b <ft-trait>)
    (leo-ss-pool <stableswap-pool-trait>)
    (leo-xyk-token-a <ft-trait>)
    (leo-xyk-token-b <ft-trait>)
    (leo-xyk-pool <xyk-pool-trait>)
    (leo-output <ft-trait>)
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

    ;; === STEP 3: EXECUTE SWAPS (only if amount > 0) ===

    ;; Swap 1: sBTC
    (if (> sbtc-usdcx-amount u0)
      (let
        (
          (swap-result (try! (as-contract (execute-swap-a
            sbtc-usdcx-amount sbtc-min-out sbtc-reversed
            sbtc-ss-token-a sbtc-ss-token-b sbtc-ss-pool
            sbtc-xyk-token-a sbtc-xyk-token-b sbtc-xyk-pool))))
          (sbtc-balance (try! (contract-call? sbtc-output get-balance (as-contract tx-sender))))
        )
        ;; Forward sBTC to investor
        (if (> sbtc-balance u0)
          (try! (as-contract (contract-call? sbtc-output transfer sbtc-balance tx-sender investor none)))
          true
        )
      )
      true
    )

    ;; Swap 2: wSTX
    (if (> wstx-usdcx-amount u0)
      (let
        (
          (swap-result (try! (as-contract (execute-swap-a
            wstx-usdcx-amount wstx-min-out wstx-reversed
            wstx-ss-token-a wstx-ss-token-b wstx-ss-pool
            wstx-xyk-token-a wstx-xyk-token-b wstx-xyk-pool))))
          (wstx-balance (try! (contract-call? wstx-output get-balance (as-contract tx-sender))))
        )
        (if (> wstx-balance u0)
          (try! (as-contract (contract-call? wstx-output transfer wstx-balance tx-sender investor none)))
          true
        )
      )
      true
    )

    ;; Swap 3: ALEX
    (if (> alex-usdcx-amount u0)
      (let
        (
          (swap-result (try! (as-contract (execute-swap-a
            alex-usdcx-amount alex-min-out alex-reversed
            alex-ss-token-a alex-ss-token-b alex-ss-pool
            alex-xyk-token-a alex-xyk-token-b alex-xyk-pool))))
          (alex-balance (try! (contract-call? alex-output get-balance (as-contract tx-sender))))
        )
        (if (> alex-balance u0)
          (try! (as-contract (contract-call? alex-output transfer alex-balance tx-sender investor none)))
          true
        )
      )
      true
    )

    ;; Swap 4: WELSH
    (if (> welsh-usdcx-amount u0)
      (let
        (
          (swap-result (try! (as-contract (execute-swap-a
            welsh-usdcx-amount welsh-min-out welsh-reversed
            welsh-ss-token-a welsh-ss-token-b welsh-ss-pool
            welsh-xyk-token-a welsh-xyk-token-b welsh-xyk-pool))))
          (welsh-balance (try! (contract-call? welsh-output get-balance (as-contract tx-sender))))
        )
        (if (> welsh-balance u0)
          (try! (as-contract (contract-call? welsh-output transfer welsh-balance tx-sender investor none)))
          true
        )
      )
      true
    )

    ;; Swap 5: LEO
    (if (> leo-usdcx-amount u0)
      (let
        (
          (swap-result (try! (as-contract (execute-swap-a
            leo-usdcx-amount leo-min-out leo-reversed
            leo-ss-token-a leo-ss-token-b leo-ss-pool
            leo-xyk-token-a leo-xyk-token-b leo-xyk-pool))))
          (leo-balance (try! (contract-call? leo-output get-balance (as-contract tx-sender))))
        )
        (if (> leo-balance u0)
          (try! (as-contract (contract-call? leo-output transfer leo-balance tx-sender investor none)))
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
      event: "investment-complete",
      investor: investor,
      total-usdcx: total-usdcx,
      net-amount: net-amount,
      fee-amount: fee-amount,
      sbtc-amount: sbtc-usdcx-amount,
      wstx-amount: wstx-usdcx-amount,
      alex-amount: alex-usdcx-amount,
      welsh-amount: welsh-usdcx-amount,
      leo-amount: leo-usdcx-amount
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
