;; =====================================================================
;; StacksIndex OneClick V23 - Simple Batch Swap
;; =====================================================================
;;
;; V23: Simplified - user swaps directly from their wallet
;; No token transfers to contract, no as-contract, no fees
;; Just batches multiple router calls in a single transaction
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

(define-constant BITFLOW-ROUTER 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2)

(define-constant ERR-SWAP-FAILED (err u1004))
(define-constant ERR-MIN-INVESTMENT (err u1010))

(define-constant MIN-INVESTMENT u100000)

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

;; Simple batch swap - user swaps directly from their wallet
;; No token transfers to contract, swaps happen directly via tx-sender
(define-public (invest-diversified
    (total-usdcx uint)

    ;; STX swap params (swap-helper-a)
    (stx-amount uint)
    (stx-min-out uint)
    (stx-ss-token-a <ft-trait>)
    (stx-ss-token-b <ft-trait>)
    (stx-ss-pool <stableswap-pool-trait>)
    (stx-xyk-token-a <ft-trait>)
    (stx-xyk-token-b <ft-trait>)
    (stx-xyk-pool <xyk-pool-trait>)

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
  )
  (begin
    ;; Validation
    (asserts! (>= total-usdcx MIN-INVESTMENT) ERR-MIN-INVESTMENT)

    ;; Execute STX swap (swap-helper-a) - directly from user wallet
    (if (> stx-amount u0)
      (try! (contract-call? BITFLOW-ROUTER swap-helper-a
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

    ;; Execute sBTC swap (swap-helper-b) - directly from user wallet
    (if (> sbtc-amount u0)
      (try! (contract-call? BITFLOW-ROUTER swap-helper-b
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

    ;; Emit event
    (print {
      event: "investment-complete-v23",
      investor: tx-sender,
      total-usdcx: total-usdcx,
      stx-amount: stx-amount,
      sbtc-amount: sbtc-amount
    })

    (ok { invested: total-usdcx })
  )
)

;; =====================
;; END OF CONTRACT
;; =====================
