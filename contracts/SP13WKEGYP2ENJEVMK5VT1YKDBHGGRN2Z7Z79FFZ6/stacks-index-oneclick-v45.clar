;; =====================================================================
;; StacksIndex OneClick V44 - Multi-Strategy Support
;; =====================================================================
;;
;; Strategies:
;; - BITCOIN_MAXI: sBTC (60%), STX (40%) - from v30
;; - MEME_HUNTER:  WELSH (30%), LEO (30%), DOG (25%), DROID (15%)
;; - DEFI_YIELD:   USDH (30%), sBTC (25%), STX (25%), stSTX (20%)
;;
;; Routers:
;; - v-1-2: SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2
;; - v-1-5: SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-5
;; - stSTX: SPQC38PW542EQJ5M11CR25P7BS1CA6QT4TBXGB3M.stableswap-stx-ststx-v-1-2
;;
;; =====================================================================

;; =====================
;; TRAITS
;; =====================

(use-trait ft-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.sip-010-trait-ft-standard-v-1-1.sip-010-trait)
(use-trait stableswap-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-4.stableswap-pool-trait)
(use-trait xyk-pool-trait 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-trait-v-1-2.xyk-pool-trait)
(use-trait stableswap-pool-trait-v12 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-trait-v-1-2.stableswap-pool-trait)

;; =====================
;; ERROR CODES
;; =====================

(define-constant ERR-SWAP-FAILED (err u1001))
(define-constant ERR-SWAP-STX-FAILED (err u1002))
(define-constant ERR-SWAP-SBTC-FAILED (err u1003))
(define-constant ERR-SWAP-WELSH-FAILED (err u1004))
(define-constant ERR-SWAP-LEO-FAILED (err u1005))
(define-constant ERR-SWAP-DOG-FAILED (err u1006))
(define-constant ERR-SWAP-DROID-FAILED (err u1007))
(define-constant ERR-SWAP-USDH-FAILED (err u1008))
(define-constant ERR-SWAP-STSTX-FAILED (err u1009))

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

;; =====================================================================
;; STRATEGY 1: BITCOIN_MAXI (from v30)
;; sBTC: 60%, STX: 40%
;; =====================================================================

(define-public (invest-bitcoin-maxi
    (total-usdcx uint)
    ;; STX (40%)
    (stx-amount uint)
    (stx-min-out uint)
    (stx-ss-token-a <ft-trait>)
    (stx-ss-token-b <ft-trait>)
    (stx-ss-pool <stableswap-pool-trait>)
    (stx-xyk-token-a <ft-trait>)
    (stx-xyk-token-b <ft-trait>)
    (stx-xyk-pool <xyk-pool-trait>)
    ;; sBTC (60%)
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
      (begin
        (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-a
          stx-amount stx-min-out none false
          { a: stx-ss-token-a, b: stx-ss-token-b }
          { a: stx-ss-pool }
          { a: stx-xyk-token-a, b: stx-xyk-token-b }
          { a: stx-xyk-pool }
        ) ERR-SWAP-STX-FAILED)
        true
      )
      true
    )
    ;; sBTC swap
    (if (> sbtc-amount u0)
      (begin
        (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-b
          sbtc-amount sbtc-min-out none false
          { a: sbtc-ss-token-a, b: sbtc-ss-token-b }
          { a: sbtc-ss-pool }
          { a: sbtc-xyk-token-a, b: sbtc-xyk-token-b, c: sbtc-xyk-token-c, d: sbtc-xyk-token-d }
          { a: sbtc-xyk-pool-a, b: sbtc-xyk-pool-b }
        ) ERR-SWAP-SBTC-FAILED)
        true
      )
      true
    )
    (var-set total-investments (+ (var-get total-investments) u1))
    (var-set total-volume (+ (var-get total-volume) total-usdcx))
    (print { event: "invest-bitcoin-maxi", investor: tx-sender, total: total-usdcx })
    (ok { invested: total-usdcx })
  )
)

;; =====================================================================
;; STRATEGY 2: MEME_HUNTER
;; WELSH: 30%, LEO: 30%, DOG: 25%, DROID: 15%
;; =====================================================================

(define-public (invest-meme-hunter
    (total-usdcx uint)
    ;; WELSH (30%) - v-1-5 swap-helper-a
    (welsh-amount uint)
    (welsh-min-out uint)
    (welsh-ss14-token-a <ft-trait>)
    (welsh-ss14-token-b <ft-trait>)
    (welsh-ss14-pool <stableswap-pool-trait>)
    (welsh-ss12-token-a <ft-trait>)
    (welsh-ss12-token-b <ft-trait>)
    (welsh-ss12-pool <stableswap-pool-trait-v12>)
    (welsh-xyk-token-a <ft-trait>)
    (welsh-xyk-token-b <ft-trait>)
    (welsh-xyk-pool <xyk-pool-trait>)
    ;; LEO (30%) - v-1-5 swap-helper-a
    (leo-amount uint)
    (leo-min-out uint)
    (leo-ss14-token-a <ft-trait>)
    (leo-ss14-token-b <ft-trait>)
    (leo-ss14-pool <stableswap-pool-trait>)
    (leo-ss12-token-a <ft-trait>)
    (leo-ss12-token-b <ft-trait>)
    (leo-ss12-pool <stableswap-pool-trait-v12>)
    (leo-xyk-token-a <ft-trait>)
    (leo-xyk-token-b <ft-trait>)
    (leo-xyk-pool <xyk-pool-trait>)
    ;; DOG (25%) - v-1-2 swap-helper-c
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
    ;; DROID (15%) - v-1-2 swap-helper-c (same structure as DOG)
    (droid-amount uint)
    (droid-min-out uint)
    (droid-ss-token-a <ft-trait>)
    (droid-ss-token-b <ft-trait>)
    (droid-ss-pool <stableswap-pool-trait>)
    (droid-xyk-token-a <ft-trait>)
    (droid-xyk-token-b <ft-trait>)
    (droid-xyk-token-c <ft-trait>)
    (droid-xyk-token-d <ft-trait>)
    (droid-xyk-token-e <ft-trait>)
    (droid-xyk-token-f <ft-trait>)
    (droid-xyk-pool-a <xyk-pool-trait>)
    (droid-xyk-pool-b <xyk-pool-trait>)
    (droid-xyk-pool-c <xyk-pool-trait>)
  )
  (begin
    ;; WELSH swap via v-1-5 router
    (if (> welsh-amount u0)
      (begin
        (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-5 swap-helper-a
          welsh-amount welsh-min-out none false
          { a: welsh-ss14-token-a, b: welsh-ss14-token-b }
          { a: welsh-ss14-pool }
          { a: welsh-ss12-token-a, b: welsh-ss12-token-b }
          { a: welsh-ss12-pool }
          { a: welsh-xyk-token-a, b: welsh-xyk-token-b }
          { a: welsh-xyk-pool }
        ) ERR-SWAP-WELSH-FAILED)
        true
      )
      true
    )
    ;; LEO swap via v-1-5 router
    (if (> leo-amount u0)
      (begin
        (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-5 swap-helper-a
          leo-amount leo-min-out none false
          { a: leo-ss14-token-a, b: leo-ss14-token-b }
          { a: leo-ss14-pool }
          { a: leo-ss12-token-a, b: leo-ss12-token-b }
          { a: leo-ss12-pool }
          { a: leo-xyk-token-a, b: leo-xyk-token-b }
          { a: leo-xyk-pool }
        ) ERR-SWAP-LEO-FAILED)
        true
      )
      true
    )
    ;; DOG swap via v-1-2 router
    (if (> dog-amount u0)
      (begin
        (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-c
          dog-amount dog-min-out none false
          { a: dog-ss-token-a, b: dog-ss-token-b }
          { a: dog-ss-pool }
          { a: dog-xyk-token-a, b: dog-xyk-token-b, c: dog-xyk-token-c, d: dog-xyk-token-d, e: dog-xyk-token-e, f: dog-xyk-token-f }
          { a: dog-xyk-pool-a, b: dog-xyk-pool-b, c: dog-xyk-pool-c }
        ) ERR-SWAP-DOG-FAILED)
        true
      )
      true
    )
    ;; DROID swap via v-1-2 router
    (if (> droid-amount u0)
      (begin
        (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-c
          droid-amount droid-min-out none false
          { a: droid-ss-token-a, b: droid-ss-token-b }
          { a: droid-ss-pool }
          { a: droid-xyk-token-a, b: droid-xyk-token-b, c: droid-xyk-token-c, d: droid-xyk-token-d, e: droid-xyk-token-e, f: droid-xyk-token-f }
          { a: droid-xyk-pool-a, b: droid-xyk-pool-b, c: droid-xyk-pool-c }
        ) ERR-SWAP-DROID-FAILED)
        true
      )
      true
    )
    (var-set total-investments (+ (var-get total-investments) u1))
    (var-set total-volume (+ (var-get total-volume) total-usdcx))
    (print { event: "invest-meme-hunter", investor: tx-sender, total: total-usdcx })
    (ok { invested: total-usdcx })
  )
)

;; =====================================================================
;; STRATEGY 3: DEFI_YIELD
;; USDH: 30%, sBTC: 25%, STX: 25%, stSTX: 20%
;; =====================================================================

(define-public (invest-defi-yield
    (total-usdcx uint)
    ;; USDH (30%) - v-1-5 swap-helper-c (stableswap only)
    (usdh-amount uint)
    (usdh-min-out uint)
    (usdh-ss14-token-a <ft-trait>)
    (usdh-ss14-token-b <ft-trait>)
    (usdh-ss14-pool <stableswap-pool-trait>)
    (usdh-ss12-token-a <ft-trait>)
    (usdh-ss12-token-b <ft-trait>)
    (usdh-ss12-pool <stableswap-pool-trait-v12>)
    ;; sBTC (25%) - v-1-2 swap-helper-b
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
    ;; STX (25%) - v-1-2 swap-helper-a
    (stx-amount uint)
    (stx-min-out uint)
    (stx-ss-token-a <ft-trait>)
    (stx-ss-token-b <ft-trait>)
    (stx-ss-pool <stableswap-pool-trait>)
    (stx-xyk-token-a <ft-trait>)
    (stx-xyk-token-b <ft-trait>)
    (stx-xyk-pool <xyk-pool-trait>)
    ;; stSTX (20%) - Two-step: USDCx -> STX -> stSTX
    (ststx-usdcx-amount uint)
    (ststx-stx-min-out uint)
    (ststx-final-min-out uint)
    (ststx-ss-token-a <ft-trait>)
    (ststx-ss-token-b <ft-trait>)
    (ststx-ss-pool <stableswap-pool-trait>)
    (ststx-xyk-token-a <ft-trait>)
    (ststx-xyk-token-b <ft-trait>)
    (ststx-xyk-pool <xyk-pool-trait>)
  )
  (begin
    ;; USDH swap via v-1-5 router (stableswap only)
    (if (> usdh-amount u0)
      (begin
        (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-5 swap-helper-c
          usdh-amount usdh-min-out none false
          { a: usdh-ss14-token-a, b: usdh-ss14-token-b }
          { a: usdh-ss14-pool }
          { a: usdh-ss12-token-a, b: usdh-ss12-token-b }
          { a: usdh-ss12-pool }
        ) ERR-SWAP-USDH-FAILED)
        true
      )
      true
    )
    ;; sBTC swap via v-1-2 router
    (if (> sbtc-amount u0)
      (begin
        (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-b
          sbtc-amount sbtc-min-out none false
          { a: sbtc-ss-token-a, b: sbtc-ss-token-b }
          { a: sbtc-ss-pool }
          { a: sbtc-xyk-token-a, b: sbtc-xyk-token-b, c: sbtc-xyk-token-c, d: sbtc-xyk-token-d }
          { a: sbtc-xyk-pool-a, b: sbtc-xyk-pool-b }
        ) ERR-SWAP-SBTC-FAILED)
        true
      )
      true
    )
    ;; STX swap via v-1-2 router
    (if (> stx-amount u0)
      (begin
        (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-a
          stx-amount stx-min-out none false
          { a: stx-ss-token-a, b: stx-ss-token-b }
          { a: stx-ss-pool }
          { a: stx-xyk-token-a, b: stx-xyk-token-b }
          { a: stx-xyk-pool }
        ) ERR-SWAP-STX-FAILED)
        true
      )
      true
    )
    ;; stSTX: Two-step swap
    (if (> ststx-usdcx-amount u0)
      (begin
        ;; Step 1: USDCx -> STX
        (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-a
          ststx-usdcx-amount ststx-stx-min-out none false
          { a: ststx-ss-token-a, b: ststx-ss-token-b }
          { a: ststx-ss-pool }
          { a: ststx-xyk-token-a, b: ststx-xyk-token-b }
          { a: ststx-xyk-pool }
        ) ERR-SWAP-STX-FAILED)
        ;; Step 2: STX -> stSTX
        (unwrap! (contract-call? 'SPQC38PW542EQJ5M11CR25P7BS1CA6QT4TBXGB3M.stableswap-stx-ststx-v-1-2 swap-x-for-y
          'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststx-token
          'SPQC38PW542EQJ5M11CR25P7BS1CA6QT4TBXGB3M.stx-ststx-lp-token-v-1-2
          ststx-stx-min-out
          ststx-final-min-out
        ) ERR-SWAP-STSTX-FAILED)
        true
      )
      true
    )
    (var-set total-investments (+ (var-get total-investments) u1))
    (var-set total-volume (+ (var-get total-volume) total-usdcx))
    (print { event: "invest-defi-yield", investor: tx-sender, total: total-usdcx })
    (ok { invested: total-usdcx })
  )
)

;; =====================================================================
;; END OF CONTRACT
;; =====================================================================
