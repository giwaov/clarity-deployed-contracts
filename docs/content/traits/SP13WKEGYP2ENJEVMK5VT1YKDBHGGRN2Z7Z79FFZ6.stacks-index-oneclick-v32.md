---
title: "Trait stacks-index-oneclick-v32"
draft: true
---
```
;; =====================================================================
;; StacksIndex OneClick V32 - Multi-AMM Support
;; =====================================================================
;;
;; Bitflow routes (xyk-pool-trait-v-1-2):
;; - STX: 2-hop, sBTC: 3-hop, DOG: 4-hop, USDH: stableswap
;;
;; Alex AMM (trait-sip-010):
;; - Direct swaps via amm-pool-v2-01
;;
;; =====================================================================

;; =====================
;; TRAITS
;; =====================

;; Bitflow traits
(use-trait ft-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait stableswap-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-4.stableswap-pool-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)

;; Alex AMM trait
(use-trait alex-ft-trait 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.trait-sip-010.sip-010-trait)

;; Velar AMM traits
(use-trait velar-ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait velar-share-fee-to-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to-trait.share-fee-to-trait)

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
;; BITFLOW SWAPS (Core routes)
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
;; ALEX AMM SWAPS
;; Uses: SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
;; Tokens must implement Alex's SIP-010 trait
;; =====================

;; Alex single swap (e.g., STX -> ALEX)
(define-public (swap-alex
    (token-x <alex-ft-trait>)
    (token-y <alex-ft-trait>)
    (factor uint)
    (dx uint)
    (min-dy uint)
  )
  (begin
    (if (> dx u0)
      (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01 swap-helper
        token-x token-y factor dx (some min-dy)
      ))
      u0
    )
    (ok true)
  )
)

;; Alex multi-hop swap (e.g., STX -> intermediate -> target)
(define-public (swap-alex-multihop
    (token-x <alex-ft-trait>)
    (token-y <alex-ft-trait>)
    (token-z <alex-ft-trait>)
    (factor-x uint)
    (factor-y uint)
    (dx uint)
    (min-dz uint)
  )
  (begin
    (if (> dx u0)
      (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01 swap-helper-a
        token-x token-y token-z factor-x factor-y dx (some min-dz)
      ))
      u0
    )
    (ok true)
  )
)

;; =====================
;; VELAR AMM SWAPS
;; Uses: SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-router
;; Requires wSTX for STX swaps: SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx
;; =====================

;; Velar swap via univ2-router
;; Params: pool-id, token0, token1, token-in, token-out, share-fee-to, amt-in, amt-out-min
(define-public (swap-velar
    (pool-id uint)
    (token0 <velar-ft-trait>)
    (token1 <velar-ft-trait>)
    (token-in <velar-ft-trait>)
    (token-out <velar-ft-trait>)
    (share-fee-to <velar-share-fee-to-trait>)
    (amt-in uint)
    (amt-out-min uint)
  )
  (begin
    (if (> amt-in u0)
      (begin
        (try! (contract-call? 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-router swap-exact-tokens-for-tokens
          pool-id
          token0
          token1
          token-in
          token-out
          share-fee-to
          amt-in
          amt-out-min
        ))
        true
      )
      true
    )
    (ok true)
  )
)

;; =====================
;; COMBINED INVEST FUNCTIONS
;; =====================

;; Invest in STX + sBTC via Bitflow (base strategy)
(define-public (invest-stx-sbtc
    (total-usdcx uint)
    ;; STX params
    (stx-amount uint)
    (stx-min-out uint)
    (stx-ss-token-a <ft-trait>)
    (stx-ss-token-b <ft-trait>)
    (stx-ss-pool <stableswap-pool-trait>)
    (stx-xyk-token-a <ft-trait>)
    (stx-xyk-token-b <ft-trait>)
    (stx-xyk-pool <xyk-pool-trait>)
    ;; sBTC params
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
    ;; STX swap
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
    ;; sBTC swap
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
    (print { event: "invest-stx-sbtc-v32", investor: tx-sender, total: total-usdcx })
    (ok { invested: total-usdcx })
  )
)

;; Invest in STX + sBTC + USDH via Bitflow
(define-public (invest-with-usdh
    (total-usdcx uint)
    ;; STX params
    (stx-amount uint)
    (stx-min-out uint)
    (stx-ss-token-a <ft-trait>)
    (stx-ss-token-b <ft-trait>)
    (stx-ss-pool <stableswap-pool-trait>)
    (stx-xyk-token-a <ft-trait>)
    (stx-xyk-token-b <ft-trait>)
    (stx-xyk-pool <xyk-pool-trait>)
    ;; sBTC params
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
    ;; USDH params
    (usdh-amount uint)
    (usdh-min-out uint)
    (usdh-ss-token-a <ft-trait>)
    (usdh-ss-token-b <ft-trait>)
    (usdh-ss-pool <stableswap-pool-trait>)
  )
  (begin
    ;; STX swap
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
    ;; sBTC swap
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
    ;; USDH swap (stableswap only)
    (if (> usdh-amount u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-swap-helper-v-1-5 swap-helper-a
        usdh-amount usdh-min-out none
        { a: usdh-ss-token-a, b: usdh-ss-token-b }
        { a: usdh-ss-pool }
      ))
      u0
    )
    (var-set total-investments (+ (var-get total-investments) u1))
    (var-set total-volume (+ (var-get total-volume) total-usdcx))
    (print { event: "invest-with-usdh-v32", investor: tx-sender, total: total-usdcx })
    (ok { invested: total-usdcx })
  )
)

;; Invest in STX + sBTC + DOG via Bitflow (BTC Maxi strategy)
(define-public (invest-btc-maxi
    (total-usdcx uint)
    ;; STX params
    (stx-amount uint)
    (stx-min-out uint)
    (stx-ss-token-a <ft-trait>)
    (stx-ss-token-b <ft-trait>)
    (stx-ss-pool <stableswap-pool-trait>)
    (stx-xyk-token-a <ft-trait>)
    (stx-xyk-token-b <ft-trait>)
    (stx-xyk-pool <xyk-pool-trait>)
    ;; sBTC params
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
    ;; DOG params (4-hop)
    (dog-amount uint)
    (dog-min-out uint)
    (dog-ss-token-a <ft-trait>)
    (dog-ss-token-b <ft-trait>)
    (dog-ss-pool <stableswap-pool-trait>)
    (dog-xyk-token-a <ft-trait>)
    (dog-xyk-token-b <ft-trait>)
    (dog-xyk-token-c <ft-trait>)
    (dog-xyk-token-d <ft-trait>)
    (dog-xyk-token-e <ft-trait>)
    (dog-xyk-token-f <ft-trait>)
    (dog-xyk-pool-a <xyk-pool-trait>)
    (dog-xyk-pool-b <xyk-pool-trait>)
    (dog-xyk-pool-c <xyk-pool-trait>)
  )
  (begin
    ;; STX swap
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
    ;; sBTC swap
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
    ;; DOG swap (4-hop)
    (if (> dog-amount u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-c
        dog-amount dog-min-out none false
        { a: dog-ss-token-a, b: dog-ss-token-b }
        { a: dog-ss-pool }
        { a: dog-xyk-token-a, b: dog-xyk-token-b, c: dog-xyk-token-c, d: dog-xyk-token-d, e: dog-xyk-token-e, f: dog-xyk-token-f }
        { a: dog-xyk-pool-a, b: dog-xyk-pool-b, c: dog-xyk-pool-c }
      ))
      u0
    )
    (var-set total-investments (+ (var-get total-investments) u1))
    (var-set total-volume (+ (var-get total-volume) total-usdcx))
    (print { event: "invest-btc-maxi-v32", investor: tx-sender, total: total-usdcx })
    (ok { invested: total-usdcx })
  )
)

;; Legacy support: invest-diversified maps to invest-stx-sbtc
(define-public (invest-diversified
    (total-usdcx uint)
    (stx-amount uint)
    (stx-min-out uint)
    (stx-ss-token-a <ft-trait>)
    (stx-ss-token-b <ft-trait>)
    (stx-ss-pool <stableswap-pool-trait>)
    (stx-xyk-token-a <ft-trait>)
    (stx-xyk-token-b <ft-trait>)
    (stx-xyk-pool <xyk-pool-trait>)
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
  (invest-stx-sbtc
    total-usdcx
    stx-amount stx-min-out
    stx-ss-token-a stx-ss-token-b stx-ss-pool
    stx-xyk-token-a stx-xyk-token-b stx-xyk-pool
    sbtc-amount sbtc-min-out
    sbtc-ss-token-a sbtc-ss-token-b sbtc-ss-pool
    sbtc-xyk-token-a sbtc-xyk-token-b sbtc-xyk-token-c sbtc-xyk-token-d
    sbtc-xyk-pool-a sbtc-xyk-pool-b
  )
)

;; =====================
;; END OF CONTRACT
;; =====================

```
