;; =====================================================================
;; StacksIndex OneClick V22 - 2 Token Support (STX + sBTC)
;; =====================================================================
;;
;; V22: INLINED router calls (no private helper functions)
;; Fixes ContractCallExpectName error by avoiding trait parameter passing
;; between private functions.
;;
;; Uses router-stableswap-xyk-multihop-v-1-2 for BOTH swap legs:
;; - STX:  swap-helper-a (stableswap + 1 XYK hop)
;; - sBTC: swap-helper-b (stableswap + 2 XYK hops)
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

(define-constant ERR-NOT-AUTHORIZED (err u1001))
(define-constant ERR-INVALID-AMOUNT (err u1002))
(define-constant ERR-SWAP-FAILED (err u1004))
(define-constant ERR-TRANSFER-FAILED (err u1005))
(define-constant ERR-CONTRACT-PAUSED (err u1007))
(define-constant ERR-MIN-INVESTMENT (err u1010))

(define-constant BP-DENOMINATOR u10000)
(define-constant MIN-INVESTMENT u100000)
(define-constant MAX-FEE u100)

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
;; PUBLIC FUNCTIONS
;; =====================

;; Main investment function - 2 tokens with INLINED router calls
(define-public (invest-diversified
    (total-usdcx uint)
    (usdcx-token <ft-trait>)

    ;; STX swap params (swap-helper-a)
    (stx-amount uint)
    (stx-min-out uint)
    (stx-ss-token-a <ft-trait>)
    (stx-ss-token-b <ft-trait>)
    (stx-ss-pool <stableswap-pool-trait>)
    (stx-xyk-token-a <ft-trait>)
    (stx-xyk-token-b <ft-trait>)
    (stx-xyk-pool <xyk-pool-trait>)
    (stx-output <ft-trait>)

    ;; sBTC swap params (swap-helper-b)
    (sbtc-amount uint)
    (sbtc-min-out uint)
    (sbtc-ss-token-a <ft-trait>)
    (sbtc-ss-token-b <ft-trait>)
    (sbtc-ss-pool <stableswap-pool-trait>)
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

    ;; === STEP 3: EXECUTE STX SWAP (INLINED swap-helper-a) ===
    (if (> stx-amount u0)
      (let
        (
          (swap-result (try! (as-contract
            (contract-call? BITFLOW-ROUTER swap-helper-a
              stx-amount
              stx-min-out
              none
              false
              { a: stx-ss-token-a, b: stx-ss-token-b }
              { a: stx-ss-pool }
              { a: stx-xyk-token-a, b: stx-xyk-token-b }
              { a: stx-xyk-pool }
            ))))
          (balance (try! (contract-call? stx-output get-balance (as-contract tx-sender))))
        )
        (if (> balance u0)
          (try! (as-contract (contract-call? stx-output transfer balance tx-sender investor none)))
          true
        )
      )
      true
    )

    ;; === STEP 4: EXECUTE sBTC SWAP (INLINED swap-helper-b) ===
    (if (> sbtc-amount u0)
      (let
        (
          (swap-result (try! (as-contract
            (contract-call? BITFLOW-ROUTER swap-helper-b
              sbtc-amount
              sbtc-min-out
              none
              false
              { a: sbtc-ss-token-a, b: sbtc-ss-token-b }
              { a: sbtc-ss-pool }
              { a: sbtc-xyk-token-a, b: sbtc-xyk-token-b, c: sbtc-xyk-token-c, d: sbtc-xyk-token-d }
              { a: sbtc-xyk-pool-a, b: sbtc-xyk-pool-b }
            ))))
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
      event: "investment-complete-v22",
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

(define-public (emergency-withdraw (token <ft-trait>) (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (as-contract (contract-call? token transfer amount tx-sender recipient none))
  )
)

;; =====================
;; END OF CONTRACT
;; =====================
