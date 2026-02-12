---
title: "Trait stacks-index-oneclick-v33"
draft: true
---
```
;; =====================================================================
;; StacksIndex OneClick V33 - Multi-AMM with Bitflow-Velar Router
;; =====================================================================
;;
;; Bitflow routes:
;; - STX: 2-hop (USDCx -> aeUSDC -> STX)
;; - sBTC: 3-hop (USDCx -> aeUSDC -> STX -> sBTC)
;; - DOG: 4-hop (USDCx -> aeUSDC -> STX -> sBTC -> DOG)
;; - USDH: stableswap (USDCx -> USDH)
;;
;; Bitflow-Velar routes:
;; - WELSH: 2-hop via router-xyk-velar (STX -> aeUSDC -> WELSH)
;; - LEO: 2-hop via router-xyk-velar (STX -> aeUSDC -> LEO)
;;
;; Combined: USDCx -> STX -> WELSH requires calling both routers
;;
;; =====================================================================

;; =====================
;; TRAITS
;; =====================

;; Bitflow traits
(use-trait ft-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait stableswap-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-4.stableswap-pool-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)
;; Note: router-xyk-velar uses xyk-pool-trait-v-1-1
(use-trait xyk-pool-trait-v11 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-1.xyk-pool-trait)

;; Velar traits (used by router-xyk-velar)
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
;; BITFLOW-VELAR COMBINED SWAPS
;; Uses router-xyk-velar-v-1-2 for meme tokens
;; =====================

;; Swap STX to WELSH/LEO via Bitflow-Velar router
;; Route: STX -> aeUSDC (XYK) -> WELSH/LEO (Velar)
(define-public (swap-stx-to-meme
    (amount uint)
    (min-received uint)
    ;; XYK params (STX -> aeUSDC)
    (xyk-pool <xyk-pool-trait-v11>)
    (x-token <ft-trait>)
    (y-token <ft-trait>)
    (xyk-reversed bool)
    ;; Velar params (aeUSDC -> WELSH/LEO)
    (velar-pool-id uint)
    (velar-token0 <velar-ft-trait>)
    (velar-token1 <velar-ft-trait>)
    (velar-token-in <velar-ft-trait>)
    (velar-token-out <velar-ft-trait>)
    (velar-share-fee-to <velar-share-fee-to-trait>)
  )
  (begin
    (if (> amount u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-xyk-velar-v-1-2 swap-helper-a
        amount
        min-received
        none
        xyk-pool
        x-token
        y-token
        xyk-reversed
        velar-pool-id
        velar-token0
        velar-token1
        velar-token-in
        velar-token-out
        velar-share-fee-to
      ))
      u0
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
    ;; STX params (2-hop)
    (stx-amount uint)
    (stx-min-out uint)
    (stx-ss-token-a <ft-trait>)
    (stx-ss-token-b <ft-trait>)
    (stx-ss-pool <stableswap-pool-trait>)
    (stx-xyk-token-a <ft-trait>)
    (stx-xyk-token-b <ft-trait>)
    (stx-xyk-pool <xyk-pool-trait>)
    ;; sBTC params (3-hop)
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
    ;; STX swap (2-hop)
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
    ;; sBTC swap (3-hop)
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
    (print { event: "invest-stx-sbtc-v33", investor: tx-sender, total: total-usdcx })
    (ok { invested: total-usdcx })
  )
)

;; Invest in STX + sBTC + DOG via Bitflow (BTC Maxi strategy)
(define-public (invest-btc-maxi
    (total-usdcx uint)
    ;; STX params (2-hop)
    (stx-amount uint)
    (stx-min-out uint)
    (stx-ss-token-a <ft-trait>)
    (stx-ss-token-b <ft-trait>)
    (stx-ss-pool <stableswap-pool-trait>)
    (stx-xyk-token-a <ft-trait>)
    (stx-xyk-token-b <ft-trait>)
    (stx-xyk-pool <xyk-pool-trait>)
    ;; sBTC params (3-hop)
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
    ;; STX swap (2-hop)
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
    ;; sBTC swap (3-hop)
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
    (print { event: "invest-btc-maxi-v33", investor: tx-sender, total: total-usdcx })
    (ok { invested: total-usdcx })
  )
)

;; Invest in STX + sBTC + WELSH + LEO via Bitflow + Bitflow-Velar (Balanced strategy)
;; Flow: USDCx -> STX (Bitflow 2-hop) + USDCx -> STX -> WELSH/LEO (Bitflow 2-hop + router-xyk-velar)
(define-public (invest-balanced
    (total-usdcx uint)
    ;; STX params (2-hop: USDCx -> aeUSDC -> STX)
    (stx-amount uint)
    (stx-min-out uint)
    (stx-ss-token-a <ft-trait>)
    (stx-ss-token-b <ft-trait>)
    (stx-ss-pool <stableswap-pool-trait>)
    (stx-xyk-token-a <ft-trait>)
    (stx-xyk-token-b <ft-trait>)
    (stx-xyk-pool <xyk-pool-trait>)
    ;; sBTC params (3-hop: USDCx -> aeUSDC -> STX -> sBTC)
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
    ;; WELSH intermediate STX amount (first swap USDCx -> STX)
    (welsh-stx-amount uint)
    (welsh-stx-min-out uint)
    (welsh-stx-ss-token-a <ft-trait>)
    (welsh-stx-ss-token-b <ft-trait>)
    (welsh-stx-ss-pool <stableswap-pool-trait>)
    (welsh-stx-xyk-token-a <ft-trait>)
    (welsh-stx-xyk-token-b <ft-trait>)
    (welsh-stx-xyk-pool <xyk-pool-trait>)
    ;; WELSH params via router-xyk-velar (STX -> aeUSDC -> WELSH)
    (welsh-min-out uint)
    (welsh-xyk-pool <xyk-pool-trait-v11>)
    (welsh-x-token <ft-trait>)
    (welsh-y-token <ft-trait>)
    (welsh-velar-pool-id uint)
    (welsh-velar-token0 <velar-ft-trait>)
    (welsh-velar-token1 <velar-ft-trait>)
    (welsh-velar-token-in <velar-ft-trait>)
    (welsh-velar-token-out <velar-ft-trait>)
    (welsh-velar-share-fee-to <velar-share-fee-to-trait>)
    ;; LEO intermediate STX amount (first swap USDCx -> STX)
    (leo-stx-amount uint)
    (leo-stx-min-out uint)
    (leo-stx-ss-token-a <ft-trait>)
    (leo-stx-ss-token-b <ft-trait>)
    (leo-stx-ss-pool <stableswap-pool-trait>)
    (leo-stx-xyk-token-a <ft-trait>)
    (leo-stx-xyk-token-b <ft-trait>)
    (leo-stx-xyk-pool <xyk-pool-trait>)
    ;; LEO params via router-xyk-velar (STX -> aeUSDC -> LEO)
    (leo-min-out uint)
    (leo-xyk-pool <xyk-pool-trait-v11>)
    (leo-x-token <ft-trait>)
    (leo-y-token <ft-trait>)
    (leo-velar-pool-id uint)
    (leo-velar-token0 <velar-ft-trait>)
    (leo-velar-token1 <velar-ft-trait>)
    (leo-velar-token-in <velar-ft-trait>)
    (leo-velar-token-out <velar-ft-trait>)
    (leo-velar-share-fee-to <velar-share-fee-to-trait>)
  )
  (let
    (
      (welsh-stx-received u0)
      (leo-stx-received u0)
    )
    ;; Direct STX allocation (2-hop)
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
    ;; sBTC allocation (3-hop)
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
    ;; WELSH allocation: First USDCx -> STX (2-hop)
    (if (> welsh-stx-amount u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-a
        welsh-stx-amount welsh-stx-min-out none false
        { a: welsh-stx-ss-token-a, b: welsh-stx-ss-token-b }
        { a: welsh-stx-ss-pool }
        { a: welsh-stx-xyk-token-a, b: welsh-stx-xyk-token-b }
        { a: welsh-stx-xyk-pool }
      ))
      u0
    )
    ;; WELSH allocation: Then STX -> WELSH via router-xyk-velar
    (if (> welsh-stx-min-out u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-xyk-velar-v-1-2 swap-helper-a
        welsh-stx-min-out welsh-min-out none
        welsh-xyk-pool welsh-x-token welsh-y-token false
        welsh-velar-pool-id welsh-velar-token0 welsh-velar-token1
        welsh-velar-token-in welsh-velar-token-out welsh-velar-share-fee-to
      ))
      u0
    )
    ;; LEO allocation: First USDCx -> STX (2-hop)
    (if (> leo-stx-amount u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-a
        leo-stx-amount leo-stx-min-out none false
        { a: leo-stx-ss-token-a, b: leo-stx-ss-token-b }
        { a: leo-stx-ss-pool }
        { a: leo-stx-xyk-token-a, b: leo-stx-xyk-token-b }
        { a: leo-stx-xyk-pool }
      ))
      u0
    )
    ;; LEO allocation: Then STX -> LEO via router-xyk-velar
    (if (> leo-stx-min-out u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-xyk-velar-v-1-2 swap-helper-a
        leo-stx-min-out leo-min-out none
        leo-xyk-pool leo-x-token leo-y-token false
        leo-velar-pool-id leo-velar-token0 leo-velar-token1
        leo-velar-token-in leo-velar-token-out leo-velar-share-fee-to
      ))
      u0
    )
    (var-set total-investments (+ (var-get total-investments) u1))
    (var-set total-volume (+ (var-get total-volume) total-usdcx))
    (print { event: "invest-balanced-v33", investor: tx-sender, total: total-usdcx })
    (ok { invested: total-usdcx })
  )
)

;; Invest in WELSH + LEO + DOG via Bitflow-Velar + Bitflow (Meme Hunter strategy)
(define-public (invest-meme-hunter
    (total-usdcx uint)
    ;; WELSH intermediate STX amount
    (welsh-stx-amount uint)
    (welsh-stx-min-out uint)
    (welsh-stx-ss-token-a <ft-trait>)
    (welsh-stx-ss-token-b <ft-trait>)
    (welsh-stx-ss-pool <stableswap-pool-trait>)
    (welsh-stx-xyk-token-a <ft-trait>)
    (welsh-stx-xyk-token-b <ft-trait>)
    (welsh-stx-xyk-pool <xyk-pool-trait>)
    ;; WELSH via router-xyk-velar
    (welsh-min-out uint)
    (welsh-xyk-pool <xyk-pool-trait-v11>)
    (welsh-x-token <ft-trait>)
    (welsh-y-token <ft-trait>)
    (welsh-velar-pool-id uint)
    (welsh-velar-token0 <velar-ft-trait>)
    (welsh-velar-token1 <velar-ft-trait>)
    (welsh-velar-token-in <velar-ft-trait>)
    (welsh-velar-token-out <velar-ft-trait>)
    (welsh-velar-share-fee-to <velar-share-fee-to-trait>)
    ;; LEO intermediate STX amount
    (leo-stx-amount uint)
    (leo-stx-min-out uint)
    (leo-stx-ss-token-a <ft-trait>)
    (leo-stx-ss-token-b <ft-trait>)
    (leo-stx-ss-pool <stableswap-pool-trait>)
    (leo-stx-xyk-token-a <ft-trait>)
    (leo-stx-xyk-token-b <ft-trait>)
    (leo-stx-xyk-pool <xyk-pool-trait>)
    ;; LEO via router-xyk-velar
    (leo-min-out uint)
    (leo-xyk-pool <xyk-pool-trait-v11>)
    (leo-x-token <ft-trait>)
    (leo-y-token <ft-trait>)
    (leo-velar-pool-id uint)
    (leo-velar-token0 <velar-ft-trait>)
    (leo-velar-token1 <velar-ft-trait>)
    (leo-velar-token-in <velar-ft-trait>)
    (leo-velar-token-out <velar-ft-trait>)
    (leo-velar-share-fee-to <velar-share-fee-to-trait>)
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
    ;; WELSH: USDCx -> STX (2-hop)
    (if (> welsh-stx-amount u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-a
        welsh-stx-amount welsh-stx-min-out none false
        { a: welsh-stx-ss-token-a, b: welsh-stx-ss-token-b }
        { a: welsh-stx-ss-pool }
        { a: welsh-stx-xyk-token-a, b: welsh-stx-xyk-token-b }
        { a: welsh-stx-xyk-pool }
      ))
      u0
    )
    ;; WELSH: STX -> WELSH via router-xyk-velar
    (if (> welsh-stx-min-out u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-xyk-velar-v-1-2 swap-helper-a
        welsh-stx-min-out welsh-min-out none
        welsh-xyk-pool welsh-x-token welsh-y-token false
        welsh-velar-pool-id welsh-velar-token0 welsh-velar-token1
        welsh-velar-token-in welsh-velar-token-out welsh-velar-share-fee-to
      ))
      u0
    )
    ;; LEO: USDCx -> STX (2-hop)
    (if (> leo-stx-amount u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-a
        leo-stx-amount leo-stx-min-out none false
        { a: leo-stx-ss-token-a, b: leo-stx-ss-token-b }
        { a: leo-stx-ss-pool }
        { a: leo-stx-xyk-token-a, b: leo-stx-xyk-token-b }
        { a: leo-stx-xyk-pool }
      ))
      u0
    )
    ;; LEO: STX -> LEO via router-xyk-velar
    (if (> leo-stx-min-out u0)
      (try! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-xyk-velar-v-1-2 swap-helper-a
        leo-stx-min-out leo-min-out none
        leo-xyk-pool leo-x-token leo-y-token false
        leo-velar-pool-id leo-velar-token0 leo-velar-token1
        leo-velar-token-in leo-velar-token-out leo-velar-share-fee-to
      ))
      u0
    )
    ;; DOG: 4-hop via Bitflow
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
    (print { event: "invest-meme-hunter-v33", investor: tx-sender, total: total-usdcx })
    (ok { invested: total-usdcx })
  )
)

;; =====================
;; END OF CONTRACT
;; =====================

```
