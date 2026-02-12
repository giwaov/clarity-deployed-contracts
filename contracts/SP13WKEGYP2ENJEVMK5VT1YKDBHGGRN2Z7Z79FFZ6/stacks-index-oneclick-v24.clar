;; =====================================================================
;; StacksIndex OneClick V24 - Simple Batch Swap (Direct Router Calls)
;; =====================================================================
;;
;; V24: No constants for router - direct contract principal in calls
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
;; PUBLIC FUNCTIONS
;; =====================

(define-public (invest-diversified
    (total-usdcx uint)

    ;; STX swap params
    (stx-amount uint)
    (stx-min-out uint)
    (stx-ss-token-a <ft-trait>)
    (stx-ss-token-b <ft-trait>)
    (stx-ss-pool <stableswap-pool-trait>)
    (stx-xyk-token-a <ft-trait>)
    (stx-xyk-token-b <ft-trait>)
    (stx-xyk-pool <xyk-pool-trait>)

    ;; sBTC swap params
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
    ;; Execute STX swap directly
    (if (> stx-amount u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-a
        stx-amount
        stx-min-out
        none
        false
        { a: stx-ss-token-a, b: stx-ss-token-b }
        { a: stx-ss-pool }
        { a: stx-xyk-token-a, b: stx-xyk-token-b }
        { a: stx-xyk-pool }
      ))
      u0
    )

    ;; Execute sBTC swap directly
    (if (> sbtc-amount u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-b
        sbtc-amount
        sbtc-min-out
        none
        false
        { a: sbtc-ss-token-a, b: sbtc-ss-token-b }
        { a: sbtc-ss-pool }
        { a: sbtc-xyk-token-a, b: sbtc-xyk-token-b, c: sbtc-xyk-token-c, d: sbtc-xyk-token-d }
        { a: sbtc-xyk-pool-a, b: sbtc-xyk-pool-b }
      ))
      u0
    )

    ;; Update stats
    (var-set total-investments (+ (var-get total-investments) u1))
    (var-set total-volume (+ (var-get total-volume) total-usdcx))

    (print { event: "invest-v24", investor: tx-sender, total: total-usdcx })

    (ok { invested: total-usdcx })
  )
)
