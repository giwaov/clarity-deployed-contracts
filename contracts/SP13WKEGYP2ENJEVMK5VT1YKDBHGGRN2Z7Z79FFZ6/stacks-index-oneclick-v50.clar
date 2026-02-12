;; =====================================================================
;; StacksIndex OneClick V44 - Multi-Strategy Support
;; =====================================================================
;;
;; Strategies:
;; - BITCOIN_MAXI: sBTC (60%), STX (40%) - from v30
;; - MEME_HUNTER:  WELSH (30%), LEO (30%), DOG (25%), DROID (15%)
;; - DEFI_YIELD:   USDH (30%), sBTC (25%), STX (25%), stSTX (20%)
;; - STACKS_BELIEVER: ALEX (35%), VELAR (35%), STX (30%)
;;
;; Routers:
;; - v-1-2: SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2
;; - v-1-5: SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-5
;; - Alex: SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01
;; - Velar: SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.path-apply_staging
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
(define-constant ERR-SWAP-ALEX-FAILED (err u1010))
(define-constant ERR-SWAP-VELAR-FAILED (err u1011))

;; =====================
;; DATA VARIABLES
;; =====================

(define-data-var total-investments uint u0)
(define-data-var total-volume uint u0)

;; =====================
;; USER TRACKING MAP
;; =====================
;; Tracks per-address: total USDCx invested and total USDCx withdrawn
;; This allows calculating profit/loss: withdrawn - invested

(define-map user-stats
  principal
  {
    total-invested: uint,    ;; Total USDCx spent on investments
    total-withdrawn: uint,   ;; Total USDCx received from sells
    invest-count: uint,      ;; Number of investment transactions
    sell-count: uint         ;; Number of sell transactions
  }
)

;; =====================
;; READ-ONLY FUNCTIONS
;; =====================

(define-read-only (get-stats)
  {
    total-investments: (var-get total-investments),
    total-volume: (var-get total-volume)
  }
)

;; Get user's investment/withdrawal stats
(define-read-only (get-user-stats (user principal))
  (default-to
    { total-invested: u0, total-withdrawn: u0, invest-count: u0, sell-count: u0 }
    (map-get? user-stats user)
  )
)

;; Get user's profit/loss (positive = profit, negative would underflow so returns 0)
(define-read-only (get-user-pnl (user principal))
  (let
    (
      (stats (get-user-stats user))
      (invested (get total-invested stats))
      (withdrawn (get total-withdrawn stats))
    )
    {
      invested: invested,
      withdrawn: withdrawn,
      profit: (if (> withdrawn invested) (- withdrawn invested) u0),
      loss: (if (> invested withdrawn) (- invested withdrawn) u0),
      is-profit: (> withdrawn invested)
    }
  )
)

;; =====================
;; PRIVATE HELPER FUNCTIONS
;; =====================

;; Update user stats after investment
(define-private (record-investment (user principal) (amount uint))
  (let
    (
      (current-stats (get-user-stats user))
    )
    (map-set user-stats user
      {
        total-invested: (+ (get total-invested current-stats) amount),
        total-withdrawn: (get total-withdrawn current-stats),
        invest-count: (+ (get invest-count current-stats) u1),
        sell-count: (get sell-count current-stats)
      }
    )
  )
)

;; Update user stats after sell
(define-private (record-withdrawal (user principal) (amount uint))
  (let
    (
      (current-stats (get-user-stats user))
    )
    (map-set user-stats user
      {
        total-invested: (get total-invested current-stats),
        total-withdrawn: (+ (get total-withdrawn current-stats) amount),
        invest-count: (get invest-count current-stats),
        sell-count: (+ (get sell-count current-stats) u1)
      }
    )
  )
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
    (record-investment tx-sender total-usdcx)
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
    (record-investment tx-sender total-usdcx)
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
    ;; stSTX: Two-step swap, get the result from first tx and use it as input for second tx
    (if (> ststx-usdcx-amount u0)
      (let
        (
          ;; Step 1: USDCx -> STX - capture the output amount
          (stx-received (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-a
            ststx-usdcx-amount ststx-stx-min-out none false
            { a: ststx-ss-token-a, b: ststx-ss-token-b }
            { a: ststx-ss-pool }
            { a: ststx-xyk-token-a, b: ststx-xyk-token-b }
            { a: ststx-xyk-pool }
          ) ERR-SWAP-STX-FAILED))
        )
        ;; Step 2: STX -> stSTX - use the actual STX received from step 1
        (unwrap! (contract-call? 'SPQC38PW542EQJ5M11CR25P7BS1CA6QT4TBXGB3M.stableswap-stx-ststx-v-1-2 swap-x-for-y
          'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststx-token
          'SPQC38PW542EQJ5M11CR25P7BS1CA6QT4TBXGB3M.stx-ststx-lp-token-v-1-2
          stx-received
          ststx-final-min-out
        ) ERR-SWAP-STSTX-FAILED)
        true
      )
      true
    )
    (var-set total-investments (+ (var-get total-investments) u1))
    (var-set total-volume (+ (var-get total-volume) total-usdcx))
    (record-investment tx-sender total-usdcx)
    (print { event: "invest-defi-yield", investor: tx-sender, total: total-usdcx })
    (ok { invested: total-usdcx })
  )
)

;; =====================================================================
;; STRATEGY 4: STACKS_BELIEVER
;; ALEX: 35%, VELAR: 35%, STX: 30%
;; All routes are two-step: USDCx -> STX first, then STX -> target token
;; =====================================================================

(define-public (invest-stacks-believer
    (total-usdcx uint)
    ;; STX (30%) - direct via Bitflow
    (stx-usdcx-amount uint)
    (stx-min-out uint)
    ;; ALEX (35%) - two-step: USDCx -> STX -> ALEX
    (alex-usdcx-amount uint)
    (alex-stx-min-out uint)
    (alex-min-out uint)
    ;; VELAR (35%) - two-step: USDCx -> STX -> VELAR
    (velar-usdcx-amount uint)
    (velar-stx-min-out uint)
    (velar-min-out uint)
  )
  (begin
    ;; STX swap (30%) - USDCx -> STX via Bitflow router-stableswap-xyk-v-1-5
    (if (> stx-usdcx-amount u0)
      (begin
        (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-v-1-5 swap-helper-a
          stx-usdcx-amount stx-min-out none false
          { a: 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx, b: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc }
          { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdcx-v-1-1 }
          { a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-1 }
          { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-1 }
        ) ERR-SWAP-STX-FAILED)
        true
      )
      true
    )
    ;; ALEX swap (35%) - Two-step: USDCx -> STX -> ALEX
    (if (> alex-usdcx-amount u0)
      (let
        (
          ;; Step 1: USDCx -> STX via Bitflow
          (stx-for-alex (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-v-1-5 swap-helper-a
            alex-usdcx-amount alex-stx-min-out none false
            { a: 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx, b: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc }
            { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdcx-v-1-1 }
            { a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-1 }
            { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-1 }
          ) ERR-SWAP-STX-FAILED))
        )
        ;; Step 2: STX -> ALEX via Alex AMM (swap-helper-a: wSTX -> wCORGI -> ALEX)
        (unwrap! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01 swap-helper-a
          'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
          'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wcorgi
          'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex
          u100000000  ;; factor-x
          u100000000  ;; factor-y
          stx-for-alex
          (some alex-min-out)
        ) ERR-SWAP-ALEX-FAILED)
        true
      )
      true
    )
    ;; VELAR swap (35%) - Two-step: USDCx -> STX -> VELAR
    (if (> velar-usdcx-amount u0)
      (let
        (
          ;; Step 1: USDCx -> STX via Bitflow
          (stx-for-velar (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-v-1-5 swap-helper-a
            velar-usdcx-amount velar-stx-min-out none false
            { a: 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx, b: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc }
            { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdcx-v-1-1 }
            { a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-1 }
            { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-1 }
          ) ERR-SWAP-STX-FAILED))
        )
        ;; Step 2: STX -> VELAR via Velar path-apply
        (unwrap! (contract-call? 'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.path-apply_staging apply
          ;; path: list of tuples defining the swap route
          (list
            {
              a: "u",
              b: 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.velar-stx,
              c: u21,
              d: 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx,
              e: 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.velar-token,
              f: false
            }
          )
          stx-for-velar  ;; amt-in
          (some 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx)         ;; token1
          (some 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.velar-token)  ;; token2
          none  ;; token3
          none  ;; token4
          none  ;; token5
          (some 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to)  ;; share-fee-to
          none none none none  ;; univ2v2-pool-1 to 4
          none none none none  ;; univ2v2-fees-1 to 4
          none none none none  ;; curve-pool-1 to 4
          none none none none  ;; curve-fees-1 to 4
          none none none none  ;; ststx-pool-1 to 4
          none none none none  ;; ststx-proxy-1 to 4
        ) ERR-SWAP-VELAR-FAILED)
        true
      )
      true
    )
    (var-set total-investments (+ (var-get total-investments) u1))
    (var-set total-volume (+ (var-get total-volume) total-usdcx))
    (record-investment tx-sender total-usdcx)
    (print { event: "invest-stacks-believer", investor: tx-sender, total: total-usdcx })
    (ok { invested: total-usdcx })
  )
)

;; =====================================================================
;; SELL FUNCTION - Convert portfolio tokens back to USDCx in one transaction
;; Supports all strategy tokens:
;; - BITCOIN_MAXI/DEFI_YIELD: STX, sBTC, stSTX, USDH
;; - MEME_HUNTER: WELSH, LEO, DOG, DROID
;; - STACKS_BELIEVER: ALEX, VELAR (+ STX)
;;
;; Routes:
;; - STX: router-stableswap-xyk-v-1-5.swap-helper-a (reversed)
;; - sBTC: router-stableswap-xyk-multihop-v-1-2.swap-helper-b (reversed)
;; - stSTX: stableswap-swap-helper-v-1-5 (stSTX->STX) then STX->USDCx
;; - WELSH: router-stableswap-xyk-multihop-v-1-2.swap-helper-b (reversed)
;; - LEO: router-stableswap-velar-v-1-5.swap-helper-a (reversed)
;; - DOG: router-stableswap-xyk-multihop-v-1-2.swap-helper-c (reversed)
;; - DROID: router-stableswap-xyk-multihop-v-1-2.swap-helper-c (reversed)
;; - USDH: stableswap-swap-helper-v-1-5.swap-helper-a
;; - ALEX: Alex AMM (ALEX->STX) then STX->USDCx
;; - VELAR: Velar path-apply (VELAR->STX) then STX->USDCx
;; =====================================================================

(define-public (sell-portfolio
    ;; STX -> USDCx (via router-stableswap-xyk-v-1-5.swap-helper-a reversed)
    (stx-amount uint)
    (stx-min-out uint)
    ;; sBTC -> USDCx (via v-1-2 swap-helper-b reversed)
    (sbtc-amount uint)
    (sbtc-min-out uint)
    ;; stSTX -> USDCx (two-step: stSTX -> STX via stableswap, then STX -> USDCx)
    (ststx-amount uint)
    (ststx-stx-min-out uint)
    (ststx-usdcx-min-out uint)
    ;; WELSH -> USDCx (via v-1-2 swap-helper-b reversed)
    (welsh-amount uint)
    (welsh-min-out uint)
    ;; LEO -> USDCx (via router-stableswap-velar-v-1-5.swap-helper-a reversed)
    (leo-amount uint)
    (leo-min-out uint)
    ;; DOG -> USDCx (via v-1-2 swap-helper-c reversed)
    (dog-amount uint)
    (dog-min-out uint)
    ;; DROID -> USDCx (via v-1-2 swap-helper-c reversed)
    (droid-amount uint)
    (droid-min-out uint)
    ;; USDH -> USDCx (via stableswap-swap-helper-v-1-5.swap-helper-a)
    (usdh-amount uint)
    (usdh-min-out uint)
    ;; ALEX -> USDCx (two-step: ALEX -> STX via Alex, then STX -> USDCx)
    (alex-amount uint)
    (alex-stx-min-out uint)
    (alex-usdcx-min-out uint)
    ;; VELAR -> USDCx (two-step: VELAR -> STX via Velar, then STX -> USDCx)
    (velar-amount uint)
    (velar-stx-min-out uint)
    (velar-usdcx-min-out uint)
  )
  (let
    (
      ;; ===== SELL STX -> USDCx =====
      (usdcx-from-stx (if (> stx-amount u0)
        (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-v-1-5 swap-helper-a
          stx-amount stx-min-out none true
          { a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, b: 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx }
          { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdcx-v-1-1 }
          { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-1, b: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc }
          { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-1 }
        ) ERR-SWAP-STX-FAILED)
        u0))
      ;; ===== SELL sBTC -> USDCx =====
      (usdcx-from-sbtc (if (> sbtc-amount u0)
        (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-b
          sbtc-amount sbtc-min-out none true
          { a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, b: 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx }
          { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdcx-v-1-1 }
          { a: 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token, b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2, c: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2, d: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc }
          { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1, b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-2 }
        ) ERR-SWAP-SBTC-FAILED)
        u0))
      ;; ===== SELL WELSH -> USDCx =====
      (usdcx-from-welsh (if (> welsh-amount u0)
        (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-b
          welsh-amount welsh-min-out none true
          { a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, b: 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx }
          { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdcx-v-1-1 }
          { a: 'SP3NE50GEXFG9SZGTT51P40X2CKYSZ5CC4ZTZ7A2G.welshcorgicoin-token, b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2, c: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2, d: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc }
          { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-welsh-stx-v-1-1, b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-2 }
        ) ERR-SWAP-WELSH-FAILED)
        u0))
      ;; ===== SELL LEO -> USDCx =====
      (usdcx-from-leo (if (> leo-amount u0)
        (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-velar-v-1-5 swap-helper-a
          leo-amount leo-min-out none true
          { a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, b: 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx }
          { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdcx-v-1-1 }
          { a: 'SP1AY6K3PQV5MRT6R4S671NWW2FRVPKM0BR162CT6.leo-token, b: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc }
          'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to
        ) ERR-SWAP-LEO-FAILED)
        u0))
      ;; ===== SELL DOG -> USDCx =====
      (usdcx-from-dog (if (> dog-amount u0)
        (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-c
          dog-amount dog-min-out none true
          { a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, b: 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx }
          { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdcx-v-1-1 }
          { a: 'SP14NS8MVBRHXMM96BQY0727AJ59SWPV7RMHC0NCG.pontis-bridge-DOG, b: 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token, c: 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token, d: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2, e: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2, f: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc }
          { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-dog-v-1-1, b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1, c: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-2 }
        ) ERR-SWAP-DOG-FAILED)
        u0))
      ;; ===== SELL DROID -> USDCx =====
      (usdcx-from-droid (if (> droid-amount u0)
        (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-multihop-v-1-2 swap-helper-c
          droid-amount droid-min-out none true
          { a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, b: 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx }
          { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdcx-v-1-1 }
          { a: 'SP2EEV5QBZA454MSMW9W3WJNRXVJF36VPV17FFKYH.DROID, b: 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token, c: 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token, d: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2, e: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2, f: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc }
          { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-droid-v-1-1, b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-sbtc-stx-v-1-1, c: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-2 }
        ) ERR-SWAP-DROID-FAILED)
        u0))
      ;; ===== SELL USDH -> USDCx =====
      (usdcx-from-usdh (if (> usdh-amount u0)
        (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-swap-helper-v-1-5 swap-helper-a
          usdh-amount usdh-min-out none
          { a: 'SPN5AKG35QZSK2M8GAMR4AFX45659RJHDW353HSG.usdh-token-v1, b: 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx }
          { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-usdh-usdcx-v-1-1 }
        ) ERR-SWAP-USDH-FAILED)
        u0))
    )
    ;; ===== TWO-STEP SWAPS (stSTX, ALEX, VELAR) =====
    ;; These require nested lets for the intermediate STX amounts

    ;; Sell stSTX -> USDCx (two-step)
    (let
      (
        (usdcx-from-ststx (if (> ststx-amount u0)
          (let
            (
              (stx-received (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-swap-helper-v-1-5 swap-helper-a
                ststx-amount ststx-stx-min-out none
                { a: 'SP4SZE494VC2YC5JYG7AYFQ44F5Q4PYV7DVMDPBG.ststx-token, b: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-2 }
                { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-stx-ststx-v-1-4 }
              ) ERR-SWAP-STSTX-FAILED))
            )
            (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-v-1-5 swap-helper-a
              stx-received ststx-usdcx-min-out none true
              { a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, b: 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx }
              { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdcx-v-1-1 }
              { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-1, b: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc }
              { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-1 }
            ) ERR-SWAP-STX-FAILED)
          )
          u0))
      )
      ;; Sell ALEX -> USDCx (two-step)
      (let
        (
          (usdcx-from-alex (if (> alex-amount u0)
            (let
              (
                (stx-from-alex (unwrap! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.amm-pool-v2-01 swap-helper
                  'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex
                  'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-wstx-v2
                  u100000000
                  alex-amount
                  (some alex-stx-min-out)
                ) ERR-SWAP-ALEX-FAILED))
              )
              (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-v-1-5 swap-helper-a
                stx-from-alex alex-usdcx-min-out none true
                { a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, b: 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx }
                { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdcx-v-1-1 }
                { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-1, b: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc }
                { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-1 }
              ) ERR-SWAP-STX-FAILED)
            )
            u0))
        )
        ;; Sell VELAR -> USDCx (two-step)
        (let
          (
            (usdcx-from-velar (if (> velar-amount u0)
              (let
                (
                  (velar-swap-result (unwrap! (contract-call? 'SP20X3DC5R091J8B6YPQT638J8NR1W83KN6TN5BJY.path-apply_staging apply
                    (list
                      {
                        a: "u",
                        b: 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.velar-stx,
                        c: u21,
                        d: 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.velar-token,
                        e: 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx,
                        f: true
                      }
                    )
                    velar-amount
                    (some 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.velar-token)
                    (some 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.wstx)
                    none none none
                    (some 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.univ2-share-fee-to)
                    none none none none
                    none none none none
                    none none none none
                    none none none none
                    none none none none
                    none none none none
                  ) ERR-SWAP-VELAR-FAILED))
                  (stx-from-velar (get amt-out (get swap1 velar-swap-result)))
                )
                (unwrap! (contract-call? 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.router-stableswap-xyk-v-1-5 swap-helper-a
                  stx-from-velar velar-usdcx-min-out none true
                  { a: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc, b: 'SP120SBRBQJ00MCWS7TM5R8WJNTTKD5K0HFRC2CNE.usdcx }
                  { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.stableswap-pool-aeusdc-usdcx-v-1-1 }
                  { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.token-stx-v-1-1, b: 'SP3Y2ZSH8P7D50B0VBTSX11S7XSG24M1VB9YFQA4K.token-aeusdc }
                  { a: 'SM1793C4R5PZ4NS4VQ4WMP7SKKYVH8JZEWSZ9HCCR.xyk-pool-stx-aeusdc-v-1-1 }
                ) ERR-SWAP-STX-FAILED)
              )
              u0))
            ;; Calculate total USDCx received
            (total-usdcx-received (+ usdcx-from-stx usdcx-from-sbtc usdcx-from-welsh usdcx-from-leo usdcx-from-dog usdcx-from-droid usdcx-from-usdh usdcx-from-ststx usdcx-from-alex usdcx-from-velar))
          )
          ;; Record the withdrawal
          (record-withdrawal tx-sender total-usdcx-received)
          (print { event: "sell-portfolio", seller: tx-sender, stx: stx-amount, sbtc: sbtc-amount, ststx: ststx-amount, welsh: welsh-amount, leo: leo-amount, dog: dog-amount, droid: droid-amount, usdh: usdh-amount, alex: alex-amount, velar: velar-amount, total-usdcx: total-usdcx-received })
          (ok { sold-stx: stx-amount, sold-sbtc: sbtc-amount, sold-ststx: ststx-amount, sold-welsh: welsh-amount, sold-leo: leo-amount, sold-dog: dog-amount, sold-droid: droid-amount, sold-usdh: usdh-amount, sold-alex: alex-amount, sold-velar: velar-amount, total-usdcx-received: total-usdcx-received })
        )
      )
    )
  )
)

;; =====================================================================
;; END OF CONTRACT
;; =====================================================================
