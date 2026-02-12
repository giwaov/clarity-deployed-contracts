;; =====================================================================
;; StacksIndex OneClick V29 - Multi-Token Bitflow Support
;; =====================================================================
;;
;; Bitflow routes:
;; - STX:   swap-helper-a (router-stableswap-xyk-multihop-v-1-2) - 2 hop
;; - sBTC:  swap-helper-b (router-stableswap-xyk-multihop-v-1-2) - 3 hop
;; - DOG:   swap-helper-c (router-stableswap-xyk-multihop-v-1-2) - 4 hop
;; - USDH:  swap-helper-a (stableswap-swap-helper-v-1-5) - stableswap only
;;
;; =====================================================================

;; =====================
;; TRAITS
;; =====================

(use-trait ft-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait stableswap-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-4.stableswap-pool-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)

;; =====================
;; DATA VARIABLES
;; =====================

(define-data-var total-investments uint u0)
(define-data-var total-volume uint u0)

;; =====================
;; READ-ONLY FUNCTIONS
;; =====================

(define-read-only (get-stats)
  {
    total-investments: (var-get total-investments),
    total-volume: (var-get total-volume)
  }
)

;; =====================
;; BITFLOW SWAPS
;; =====================

;; Bitflow 2-hop: STX (USDCx -> aeUSDC -> STX)
(define-public (swap-bitflow-2hop
    (amount uint)
    (min-out uint)
    (ss-token-a <ft-trait>)
    (ss-token-b <ft-trait>)
    (ss-pool <stableswap-pool-trait>)
    (xyk-token-a <ft-trait>)
    (xyk-token-b <ft-trait>)
    (xyk-pool <xyk-pool-trait>)
  )
  (begin
    (if (> amount u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-a
        amount min-out none false
        { a: ss-token-a, b: ss-token-b }
        { a: ss-pool }
        { a: xyk-token-a, b: xyk-token-b }
        { a: xyk-pool }
      ))
      u0
    )
    (ok true)
  )
)

;; Bitflow 3-hop: sBTC (USDCx -> aeUSDC -> STX -> sBTC)
(define-public (swap-bitflow-3hop
    (amount uint)
    (min-out uint)
    (ss-token-a <ft-trait>)
    (ss-token-b <ft-trait>)
    (ss-pool <stableswap-pool-trait>)
    (xyk-token-a <ft-trait>)
    (xyk-token-b <ft-trait>)
    (xyk-token-c <ft-trait>)
    (xyk-token-d <ft-trait>)
    (xyk-pool-a <xyk-pool-trait>)
    (xyk-pool-b <xyk-pool-trait>)
  )
  (begin
    (if (> amount u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-b
        amount min-out none false
        { a: ss-token-a, b: ss-token-b }
        { a: ss-pool }
        { a: xyk-token-a, b: xyk-token-b, c: xyk-token-c, d: xyk-token-d }
        { a: xyk-pool-a, b: xyk-pool-b }
      ))
      u0
    )
    (ok true)
  )
)

;; Bitflow 4-hop: DOG (USDCx -> aeUSDC -> STX -> sBTC -> DOG)
(define-public (swap-bitflow-4hop
    (amount uint)
    (min-out uint)
    (ss-token-a <ft-trait>)
    (ss-token-b <ft-trait>)
    (ss-pool <stableswap-pool-trait>)
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
  (begin
    (if (> amount u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-c
        amount min-out none false
        { a: ss-token-a, b: ss-token-b }
        { a: ss-pool }
        { a: xyk-token-a, b: xyk-token-b, c: xyk-token-c, d: xyk-token-d, e: xyk-token-e, f: xyk-token-f }
        { a: xyk-pool-a, b: xyk-pool-b, c: xyk-pool-c }
      ))
      u0
    )
    (ok true)
  )
)

;; Bitflow stableswap only: USDH (USDCx -> USDH)
(define-public (swap-bitflow-stableswap
    (amount uint)
    (min-out uint)
    (ss-token-a <ft-trait>)
    (ss-token-b <ft-trait>)
    (ss-pool <stableswap-pool-trait>)
  )
  (begin
    (if (> amount u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-swap-helper-v-1-5 swap-helper-a
        amount min-out none
        { a: ss-token-a, b: ss-token-b }
        { a: ss-pool }
      ))
      u0
    )
    (ok true)
  )
)

;; =====================
;; COMBINED INVEST FUNCTIONS
;; =====================

;; Invest in STX + sBTC via Bitflow
(define-public (invest-diversified
    (total-usdcx uint)
    ;; STX
    (stx-amount uint)
    (stx-min-out uint)
    (stx-ss-token-a <ft-trait>)
    (stx-ss-token-b <ft-trait>)
    (stx-ss-pool <stableswap-pool-trait>)
    (stx-xyk-token-a <ft-trait>)
    (stx-xyk-token-b <ft-trait>)
    (stx-xyk-pool <xyk-pool-trait>)
    ;; sBTC
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
  )
  (begin
    ;; STX
    (if (> stx-amount u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-a
        stx-amount stx-min-out none false
        { a: stx-ss-token-a, b: stx-ss-token-b }
        { a: stx-ss-pool }
        { a: stx-xyk-token-a, b: stx-xyk-token-b }
        { a: stx-xyk-pool }
      ))
      u0
    )
    ;; sBTC
    (if (> sbtc-amount u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-b
        sbtc-amount sbtc-min-out none false
        { a: sbtc-ss-token-a, b: sbtc-ss-token-b }
        { a: sbtc-ss-pool }
        { a: sbtc-xyk-token-a, b: sbtc-xyk-token-b, c: sbtc-xyk-token-c, d: sbtc-xyk-token-d }
        { a: sbtc-xyk-pool-a, b: sbtc-xyk-pool-b }
      ))
      u0
    )
    (var-set total-investments (+ (var-get total-investments) u1))
    (var-set total-volume (+ (var-get total-volume) total-usdcx))
    (print { event: "invest-diversified-v29", investor: tx-sender, total: total-usdcx })
    (ok { invested: total-usdcx })
  )
)

;; =====================
;; END OF CONTRACT
;; =====================
