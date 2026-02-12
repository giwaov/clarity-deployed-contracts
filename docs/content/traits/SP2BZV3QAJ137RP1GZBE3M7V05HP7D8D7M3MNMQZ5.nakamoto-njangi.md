---
title: "Trait nakamoto-njangi"
draft: true
---
```
(use-trait sip-010-trait 'SP3FBR2AGK5H9QBDH3EEN6DF8EK8JY7RX8QJ5SVTE.sip-010-trait-ft-standard.sip-010-trait)

;; CONSTANTS
(define-constant ERR_NOT_INITIALIZED (err u501))
(define-constant ERR_ALREADY_INITIALIZED (err u500))
(define-constant ERR_INSUFFICIENT_TRADING_LIQUIDITY (err u3005))
(define-constant ERR_NOT_ENOUGH_TOKEN_BALANCE (err u1004))
(define-constant ERR_INVALID_AMOUNT (err u3001))
(define-constant ERR_INVALID_OVERTAKE_AMOUNT (err u503))
(define-constant ERR_UNAUTHORIZED (err u401))
(define-constant ERR_CANNOT_SELL_WHILE_MAJORITY_HOLDER (err u504))
(define-constant ERR_SLIPPAGE_EXCEEDED (err u505)) ;; Cost exceeds max-cost or received below min-received
(define-constant ERR_NOT_CURRENT_MARKET_MAKER (err u508)) ;; Not the current market maker
(define-constant ERR_CANNOT_UNLOCK_BELOW_THRESHOLD (err u506))
(define-constant ERR_CANNOT_WITHDRAW_BELOW_THRESHOLD (err u507))

(define-constant DEX_ADDRESS (as-contract tx-sender))
(define-constant TOKEN_DECIMALS u1000000) ;; 10^6 - for converting token amounts to human-readable (Teiko tokens have 6 decimals)
(define-constant INITIAL_VIRTUAL_SBTC u15000) ;; 15k satoshis (adjusted for bonding curve pricing - optimized for affordability)
(define-constant MIN_INITIAL_DEPOSIT u100000000000) ;; 100k tokens (100,000 * 10^6)
(define-constant OVERTAKE_INCREMENT u10000000000) ;; 10k tokens (10,000 * 10^6) (FEATURE 1: changed from 100k)
(define-constant DEFEND_MM_INCREMENT u100000000000) ;; 100k tokens (100,000 * 10^6) (FEATURE 4: for defend function)
(define-constant TRADE_LIMIT u2000000000) ;; 2k tokens (2,000 * 10^6)
(define-constant TRADE_LIMIT_10K u10000000000) ;; 10k tokens (10,000 * 10^6)
(define-constant LOCK_INCREMENT u2000000000) ;; 2k tokens (2,000 * 10^6) - increment for majority holder
(define-constant MIN_UNLOCK_THRESHOLD u1500) ;; Minimum threshold (1500 sats)
(define-constant MAX_UNLOCK_THRESHOLD u1000000) ;; Maximum cap (1M sats)

;; DATA VARIABLES
(define-data-var token-balance uint u0) ;; Trading pool (bonding curve)
(define-data-var sats-available-for-trading uint u0) ;; Real SBTC available for trading (derived from total - accumulated)
(define-data-var virtual-sbtc-amount uint INITIAL_VIRTUAL_SBTC) ;; Virtual balance for curve math
(define-data-var initialized bool false)
(define-data-var market-manager-address (optional principal) none) ;; Market maker address
(define-data-var market-maker-deposit uint u0) ;; Current MM deposit amount (supply cap)
(define-data-var accumulated-trading-fees uint u0) ;; Current Majority holder rewards (15% fees)
(define-data-var majority-holder-address (optional principal) none) ;; Current majority holder address
(define-data-var locked-tokens uint u0) ;; Total tokens currently locked (only one person at a time)
(define-data-var total-majority-holder-rewards-paid-out uint u0) ;; Lifetime total fees withdrawn by majority holders
(define-data-var total-market-maker-fees-paid uint u0) ;; Lifetime total fees paid to market makers
(define-data-var total-sbtc-invested-by-traders uint u0) ;; Lifetime total SBTC invested by all traders
(define-data-var total-sbtc-received-by-traders uint u0) ;; Lifetime total SBTC received by all traders from sells
(define-map curve-tokens-bought {holder: principal} uint) ;; Tracks tokens bought from bonding curve only
(define-map sbtc-invested {holder: principal} uint) ;; Tracks total SBTC spent on buys (lifetime, never resets)
(define-map current-sats-invested {holder: principal} uint) ;; Tracks SBTC spent for current position (resets to 0 on sell-all)
(define-map sbtc-received {holder: principal} uint) ;; Tracks total SBTC received from sells
(define-map mh-rewards-received {holder: principal} uint) ;; Lifetime MH rewards per user
(define-map mm-fees-earned {holder: principal} uint) ;; Lifetime MM fees per user
(define-data-var last-highest-withdrawal uint u0) ;; Tracks highest withdrawal amount
(define-data-var unlock-threshold-permanent uint u0) ;; Permanent threshold if > 1M
(define-data-var total-sbtc-balance uint u0) ;; Explicitly track total SBTC in contract (for debugging balance mismatches)

;; ========================================
;; MARKET MAKER FUNCTIONS
;; ========================================
;; Become market maker: Creates market if none exists, or overtakes existing MM
;; If no market exists: Deposits 100k tokens to create market
;; If market exists: Pays current MM deposit + 10k, old MM gets refunded
;; FEATURE 2: max-tokens parameter for slippage protection (human-readable format)
(define-public (become-market-maker (max-tokens uint))
  (begin
    (if (is-eq (var-get initialized) false)
      ;; Create market (first time)
      (let (
        (max-tokens-raw (* max-tokens TOKEN_DECIMALS)) ;; Convert to raw units
        (required-amount MIN_INITIAL_DEPOSIT) ;; 100k tokens
      )
        ;; FEATURE 2: Slippage protection
        (asserts! (<= required-amount max-tokens-raw) ERR_SLIPPAGE_EXCEEDED)
        (try! (contract-call? 'SP1T0VY3DNXRVP6HBM75DFWW0199CR0X15PC1D81B.teiko-token-stxcity
               transfer required-amount tx-sender DEX_ADDRESS (some 0x00)))
        (var-set token-balance required-amount)
        (var-set market-manager-address (some tx-sender))
        (var-set market-maker-deposit required-amount)
        (var-set initialized true)
        (ok true)
      )
      ;; Overtake existing MM (FEATURE 1: now only +10k instead of +100k)
      (let (
        (max-tokens-raw (* max-tokens TOKEN_DECIMALS)) ;; Convert to raw units
        (old-market-maker-deposit (var-get market-maker-deposit))
        (old-market-maker-address (unwrap! (var-get market-manager-address) ERR_NOT_INITIALIZED))
        (required-amount (+ old-market-maker-deposit OVERTAKE_INCREMENT)) ;; Current + 10k (FEATURE 1)
        (net-tokens-to-add OVERTAKE_INCREMENT) ;; Only add the 10k increment (FEATURE 1)
      )
        (asserts! (> required-amount u0) ERR_NOT_INITIALIZED)
        ;; FEATURE 2: Slippage protection
        (asserts! (<= required-amount max-tokens-raw) ERR_SLIPPAGE_EXCEEDED)
        ;; New MM pays full amount (old-deposit + 10k)
        (try! (contract-call? 'SP1T0VY3DNXRVP6HBM75DFWW0199CR0X15PC1D81B.teiko-token-stxcity
               transfer required-amount tx-sender DEX_ADDRESS (some 0x00)))
        ;; Old MM gets refunded from new MM's payment (their original deposit)
        (try! (as-contract (contract-call? 'SP1T0VY3DNXRVP6HBM75DFWW0199CR0X15PC1D81B.teiko-token-stxcity
               transfer old-market-maker-deposit DEX_ADDRESS old-market-maker-address (some 0x00))))
        ;; Update MM info
        (var-set market-manager-address (some tx-sender))
        (var-set market-maker-deposit required-amount)
        ;; Only add net increment to token-balance (10k tokens - FEATURE 1)
        (var-set token-balance (+ (var-get token-balance) net-tokens-to-add))
        (ok true)
      )
    )
  )
)

;; FEATURE 4: Defend Market Maker - Current MM can add 100k tokens to their existing position
;; This increases their deposit and the token balance by 100k tokens
(define-public (defend-market-maker)
  (begin
    (asserts! (is-eq (var-get initialized) true) ERR_NOT_INITIALIZED)
    (let (
      (current-mm (unwrap! (var-get market-manager-address) ERR_NOT_INITIALIZED))
      (current-deposit (var-get market-maker-deposit))
      (new-deposit (+ current-deposit DEFEND_MM_INCREMENT)) ;; Add 100k tokens
    )
      (asserts! (is-eq tx-sender current-mm) ERR_NOT_CURRENT_MARKET_MAKER)
      ;; Transfer 100k tokens from MM to contract (will fail naturally if insufficient balance)
      (try! (contract-call? 'SP1T0VY3DNXRVP6HBM75DFWW0199CR0X15PC1D81B.teiko-token-stxcity
             transfer DEFEND_MM_INCREMENT tx-sender DEX_ADDRESS (some 0x00)))
      ;; Update MM deposit and token balance
      (var-set market-maker-deposit new-deposit)
      (var-set token-balance (+ (var-get token-balance) DEFEND_MM_INCREMENT))
      (ok true)
    )
  )
)

;; ========================================
;; TRADING FUNCTIONS
;; ========================================
;; Buy: Flexible token amount (in thousands), 6% fee to market maker, 15% fee to majority holder pot
;; Uses working bonding curve logic from testnet version
;; token-amount-thousands: Amount in thousands (1 = 1k tokens, 5 = 5k tokens, 10 = 10k tokens, etc.)
;; max-cost: Maximum SBTC user is willing to pay (slippage protection)
(define-public (buy-tokens (token-amount-thousands uint) (max-cost uint))
  (begin
    (asserts! (is-eq (var-get initialized) true) ERR_NOT_INITIALIZED)
    (let (
      (tokens-out (* token-amount-thousands u1000 TOKEN_DECIMALS)) ;; Convert thousands to raw
      (current-sbtc-balance (+ (var-get sats-available-for-trading) (var-get virtual-sbtc-amount)))
      (current-token-balance (var-get token-balance))
      (k (* current-token-balance current-sbtc-balance))
      (new-token-balance (- current-token-balance tokens-out))
      (new-sbtc-balance (/ k new-token-balance))
      (net-sbtc-needed (- new-sbtc-balance current-sbtc-balance))
      (recipient tx-sender)
      (market-manager (unwrap! (var-get market-manager-address) ERR_NOT_INITIALIZED))
      (mm-fee (/ (* net-sbtc-needed u600) u10000)) ;; 6% fee to market maker
      (mh-fee (/ (* net-sbtc-needed u1500) u10000)) ;; 15% fee to majority holder pot
      (sbtc-after-fees (- net-sbtc-needed (+ mm-fee mh-fee))) ;; Net SBTC after 21% fees
    )
      (asserts! (>= current-token-balance tokens-out) ERR_INSUFFICIENT_TRADING_LIQUIDITY)
      (asserts! (> new-token-balance u0) ERR_INSUFFICIENT_TRADING_LIQUIDITY)
      (asserts! (> net-sbtc-needed u0) ERR_INVALID_AMOUNT)
      (asserts! (> sbtc-after-fees u0) ERR_INVALID_AMOUNT) ;; Ensure fees don't consume entire amount
      ;; Slippage protection: actual cost must not exceed max-cost
      (asserts! (<= net-sbtc-needed max-cost) ERR_SLIPPAGE_EXCEEDED)
      (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token 
        transfer net-sbtc-needed tx-sender DEX_ADDRESS (some 0x00)))
      ;; Transfer tokens to user
      (try! (as-contract (contract-call? 'SP1T0VY3DNXRVP6HBM75DFWW0199CR0X15PC1D81B.teiko-token-stxcity
        transfer tokens-out DEX_ADDRESS recipient (some 0x00))))
      ;; Pay market maker fee (6%)
      (try! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token 
        transfer mm-fee DEX_ADDRESS market-manager (some 0x00))))
      ;; Add majority holder fee to pot (15%)
      (var-set accumulated-trading-fees (+ (var-get accumulated-trading-fees) mh-fee))
      ;; Update total SBTC balance tracking (contract receives: sbtc-after-fees + mh-fee, mm-fee paid out immediately)
      (var-set total-sbtc-balance (+ (var-get total-sbtc-balance) sbtc-after-fees mh-fee))
      ;; Derive sats-available-for-trading from total - accumulated (ensures it's always in sync)
      (var-set sats-available-for-trading (- (var-get total-sbtc-balance) (var-get accumulated-trading-fees)))
      (var-set token-balance new-token-balance)
      ;; Track lifetime MM fees paid
      (var-set total-market-maker-fees-paid (+ (var-get total-market-maker-fees-paid) mm-fee))
      ;; Track per-user MM fees
      (let ((current-mm-fees (default-to u0 (map-get? mm-fees-earned {holder: market-manager}))))
        (map-set mm-fees-earned {holder: market-manager} (+ current-mm-fees mm-fee))
      )
      ;; Track curve tokens bought (exactly what user received)
      (let (
        (current-curve-tokens (default-to u0 (map-get? curve-tokens-bought {holder: tx-sender})))
      )
        (map-set curve-tokens-bought {holder: tx-sender} (+ current-curve-tokens tokens-out))
      )
      ;; Track SBTC invested (total SBTC spent - lifetime, never resets)
      (let (
        (current-invested (default-to u0 (map-get? sbtc-invested {holder: tx-sender})))
      )
        (map-set sbtc-invested {holder: tx-sender} (+ current-invested net-sbtc-needed))
      )
      ;; Track current position sats invested (resets to 0 on sell-all)
      (let (
        (current-position-invested (default-to u0 (map-get? current-sats-invested {holder: tx-sender})))
      )
        (map-set current-sats-invested {holder: tx-sender} (+ current-position-invested net-sbtc-needed))
      )
      ;; Track total SBTC invested by all traders (global)
      (var-set total-sbtc-invested-by-traders (+ (var-get total-sbtc-invested-by-traders) net-sbtc-needed))
      (ok tokens-out)
    )
  )
)

;; Sell all ownership: Sells ALL tokens user has accumulated, 6% fee to market maker, 15% fee to majority holder pot
;; Uses working bonding curve logic from testnet version
;; min-received: Minimum SBTC user is willing to receive after fees (slippage protection)
(define-public (sell-all-ownership (min-received uint))
  (begin
    (asserts! (is-eq (var-get initialized) true) ERR_NOT_INITIALIZED)
    ;; Majority holder cannot sell tokens
    (let ((current-majority (var-get majority-holder-address)))
      (asserts! (not (is-eq current-majority (some tx-sender))) ERR_CANNOT_SELL_WHILE_MAJORITY_HOLDER)
    )
    ;; Cannot sell until there's actual SBTC liquidity from buys
    (asserts! (> (var-get sats-available-for-trading) u0) ERR_INSUFFICIENT_TRADING_LIQUIDITY)
    (let (
      (user-curve-tokens (default-to u0 (map-get? curve-tokens-bought {holder: tx-sender})))
    )
      ;; Must have tokens to sell
      (asserts! (> user-curve-tokens u0) ERR_NOT_ENOUGH_TOKEN_BALANCE)
      (let (
        (available-sbtc (var-get sats-available-for-trading))
        (current-sbtc-balance (+ available-sbtc (var-get virtual-sbtc-amount)))
        (current-token-balance (var-get token-balance))
        (k (* current-token-balance current-sbtc-balance))
        (new-token-balance (+ current-token-balance user-curve-tokens))
        (new-sbtc-balance (/ k new-token-balance))
        (sbtc-out (- current-sbtc-balance new-sbtc-balance))
        (recipient tx-sender)
        (market-manager (unwrap! (var-get market-manager-address) ERR_NOT_INITIALIZED))
        ;; Cap sbtc-out to available real SBTC before calculating fees
        (capped-sbtc-out (if (>= sbtc-out available-sbtc) available-sbtc sbtc-out))
        (mm-fee (/ (* capped-sbtc-out u600) u10000)) ;; 6% fee to market maker
        (mh-fee (/ (* capped-sbtc-out u1500) u10000)) ;; 15% fee to majority holder pot
        (sbtc-after-fees (- capped-sbtc-out (+ mm-fee mh-fee))) ;; Net SBTC after 21% fees
        ;; Total amount we actually pay out (MM fee + user payment, MH fee stays in contract)
        (amount-to-pay-out (+ mm-fee sbtc-after-fees))
      )
        ;; Validate bonding curve calculation
        (asserts! (> new-token-balance u0) ERR_INSUFFICIENT_TRADING_LIQUIDITY)
        (asserts! (> sbtc-out u0) ERR_INVALID_AMOUNT)
        (asserts! (> sbtc-after-fees u0) ERR_INVALID_AMOUNT) ;; Ensure fees don't consume entire amount
        (asserts! (> mm-fee u0) ERR_INVALID_AMOUNT) ;; Ensure MM fee is valid
        ;; Slippage protection: actual received must be at least min-received
        (asserts! (>= sbtc-after-fees min-received) ERR_SLIPPAGE_EXCEEDED)
        ;; Check liquidity: must have enough to pay MM fee + user payment
        (asserts! (>= available-sbtc amount-to-pay-out) ERR_INSUFFICIENT_TRADING_LIQUIDITY)
        (try! (contract-call? 'SP1T0VY3DNXRVP6HBM75DFWW0199CR0X15PC1D81B.teiko-token-stxcity
          transfer user-curve-tokens tx-sender DEX_ADDRESS (some 0x00)))
        ;; Pay market maker fee (6%)
        (try! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token 
          transfer mm-fee DEX_ADDRESS market-manager (some 0x00))))
        ;; Pay user (after 21% fees)
        (try! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token 
          transfer sbtc-after-fees DEX_ADDRESS recipient (some 0x00))))
        ;; Add majority holder fee to pot (15% - stays in contract)
        (var-set accumulated-trading-fees (+ (var-get accumulated-trading-fees) mh-fee))
        ;; Update total SBTC balance tracking (contract pays out: amount-to-pay-out, keeps: mh-fee)
        (var-set total-sbtc-balance (- (var-get total-sbtc-balance) amount-to-pay-out))
        ;; Derive sats-available-for-trading from total - accumulated (ensures it's always in sync)
        (var-set sats-available-for-trading (- (var-get total-sbtc-balance) (var-get accumulated-trading-fees)))
        (var-set token-balance new-token-balance)
        ;; Track lifetime MM fees paid
        (var-set total-market-maker-fees-paid (+ (var-get total-market-maker-fees-paid) mm-fee))
        ;; Track per-user MM fees
        (let ((current-mm-fees (default-to u0 (map-get? mm-fees-earned {holder: market-manager}))))
          (map-set mm-fees-earned {holder: market-manager} (+ current-mm-fees mm-fee))
        )
        ;; Track SBTC received by user
        (let (
          (current-received (default-to u0 (map-get? sbtc-received {holder: tx-sender})))
        )
          (map-set sbtc-received {holder: tx-sender} (+ current-received sbtc-after-fees))
        )
        ;; Track total SBTC received by all traders (global)
        (var-set total-sbtc-received-by-traders (+ (var-get total-sbtc-received-by-traders) sbtc-after-fees))
        ;; Reset curve tokens tracking (user sold all their curve-bought tokens)
        (map-set curve-tokens-bought {holder: tx-sender} u0)
        ;; Reset current position sats invested (user sold out, position is now zero)
        (map-set current-sats-invested {holder: tx-sender} u0)
        (ok sbtc-after-fees)
      )
    )
  )
)


;; ========================================
;; MAJORITY HOLDER FUNCTIONS
;; ========================================
;; Become majority holder: Locks tokens bought from curve (starts at 2k, increments of 2k)
;; If no majority holder: Lock 2k tokens
;; If current holder: Add 2k more tokens
;; If someone else: Lock current + 2k, old holder gets refunded
;; FEATURE 3: max-tokens parameter for slippage protection (human-readable format)
(define-public (become-majority-holder (max-tokens uint))
  (begin
    (asserts! (is-eq (var-get initialized) true) ERR_NOT_INITIALIZED)
    (let (
      (max-tokens-raw (* max-tokens TOKEN_DECIMALS)) ;; Convert to raw units
      (current-majority (var-get majority-holder-address))
      (current-locked (var-get locked-tokens))
    )
      (if (is-none current-majority)
        ;; No majority holder exists: Lock 2k tokens
        (let (
          (required-amount LOCK_INCREMENT) ;; 2k tokens
          (user-curve-tokens (default-to u0 (map-get? curve-tokens-bought {holder: tx-sender})))
        )
          ;; FEATURE 3: Slippage protection
          (asserts! (<= required-amount max-tokens-raw) ERR_SLIPPAGE_EXCEEDED)
          (asserts! (>= user-curve-tokens required-amount) ERR_NOT_ENOUGH_TOKEN_BALANCE)
          (try! (contract-call? 'SP1T0VY3DNXRVP6HBM75DFWW0199CR0X15PC1D81B.teiko-token-stxcity
                 transfer required-amount tx-sender DEX_ADDRESS (some 0x00)))
          (var-set majority-holder-address (some tx-sender))
          (var-set locked-tokens required-amount)
          ;; Subtract from curve-tokens-bought (can't sell locked tokens)
          (map-set curve-tokens-bought {holder: tx-sender} (- user-curve-tokens required-amount))
          (ok true)
        )
        ;; Majority holder exists
        (let (
          (majority-holder (unwrap-panic current-majority))
        )
          (if (is-eq tx-sender majority-holder)
            ;; Current holder: Add 2k more
            (let (
              (required-amount LOCK_INCREMENT) ;; 2k tokens
              (user-curve-tokens (default-to u0 (map-get? curve-tokens-bought {holder: tx-sender})))
              (new-locked-amount (+ current-locked required-amount))
            )
              ;; FEATURE 3: Slippage protection
              (asserts! (<= required-amount max-tokens-raw) ERR_SLIPPAGE_EXCEEDED)
              (asserts! (>= user-curve-tokens required-amount) ERR_NOT_ENOUGH_TOKEN_BALANCE)
              (try! (contract-call? 'SP1T0VY3DNXRVP6HBM75DFWW0199CR0X15PC1D81B.teiko-token-stxcity
                     transfer required-amount tx-sender DEX_ADDRESS (some 0x00)))
              (var-set locked-tokens new-locked-amount)
              ;; Subtract from curve-tokens-bought
              (map-set curve-tokens-bought {holder: tx-sender} (- user-curve-tokens required-amount))
              (ok true)
            )
            ;; Different person: Overtake (lock current + 2k, refund old holder)
            (let (
              (required-amount (+ current-locked LOCK_INCREMENT))
              (user-curve-tokens (default-to u0 (map-get? curve-tokens-bought {holder: tx-sender})))
              (old-mh-curve-tokens (default-to u0 (map-get? curve-tokens-bought {holder: majority-holder})))
            )
              ;; FEATURE 3: Slippage protection
              (asserts! (<= required-amount max-tokens-raw) ERR_SLIPPAGE_EXCEEDED)
              (asserts! (>= user-curve-tokens required-amount) ERR_NOT_ENOUGH_TOKEN_BALANCE)
              (try! (contract-call? 'SP1T0VY3DNXRVP6HBM75DFWW0199CR0X15PC1D81B.teiko-token-stxcity
                     transfer required-amount tx-sender DEX_ADDRESS (some 0x00)))
              ;; Refund old holder's tokens
              (try! (as-contract (contract-call? 'SP1T0VY3DNXRVP6HBM75DFWW0199CR0X15PC1D81B.teiko-token-stxcity
                     transfer current-locked DEX_ADDRESS majority-holder (some 0x00))))
              ;; Restore old MH's curve-tokens-bought (they can now sell their refunded tokens)
              (map-set curve-tokens-bought {holder: majority-holder} (+ old-mh-curve-tokens current-locked))
              ;; Update majority holder
              (var-set majority-holder-address (some tx-sender))
              (var-set locked-tokens required-amount)
              ;; Subtract from new holder's curve-tokens-bought
              (map-set curve-tokens-bought {holder: tx-sender} (- user-curve-tokens required-amount))
              (ok true)
            )
          )
        )
      )
    )
  )
)

;; ========================================
;; FEE MANAGEMENT
;; ========================================
;; Claim Current Majority holder rewards (only current majority holder can claim)
;; FEATURES 5-7: Adds threshold check and withdrawal tracking
;; FEATURE 8: Adds hard reset when MM is also MH
(define-public (claim-rewards)
  (begin
    (asserts! (is-eq (var-get initialized) true) ERR_NOT_INITIALIZED)
    (let (
      (majority-holder (unwrap! (var-get majority-holder-address) ERR_NOT_INITIALIZED))
      (market-maker (unwrap! (var-get market-manager-address) ERR_NOT_INITIALIZED))
      (fees-to-claim (var-get accumulated-trading-fees))
      (is-mm-also-mh (is-eq tx-sender market-maker))
      (recipient tx-sender)  ;; Capture user address for token refund
    )
      (asserts! (is-eq tx-sender majority-holder) ERR_NOT_INITIALIZED)
      (asserts! (> fees-to-claim u0) ERR_NOT_ENOUGH_TOKEN_BALANCE)
      ;; Validate that fees-to-claim matches accumulated-trading-fees (safety check)
      (asserts! (is-eq fees-to-claim (var-get accumulated-trading-fees)) ERR_INVALID_AMOUNT)
      ;; Validate that contract has sufficient SBTC balance (rewards come only from accumulated-trading-fees)
      (let ((current-total-balance (var-get total-sbtc-balance)))
        (asserts! (>= current-total-balance fees-to-claim) ERR_INSUFFICIENT_TRADING_LIQUIDITY)
      )
      (if is-mm-also-mh
        ;; FEATURE 8: HARD RESET - MM is also MH
        (let ((locked-tokens-to-refund (var-get locked-tokens)))
          ;; Reset threshold variables
          (var-set unlock-threshold-permanent u0)
          (var-set last-highest-withdrawal u0)
          ;; Refund locked tokens
          (if (> locked-tokens-to-refund u0)
            (begin
              (try! (as-contract (contract-call? 'SP1T0VY3DNXRVP6HBM75DFWW0199CR0X15PC1D81B.teiko-token-stxcity
                transfer locked-tokens-to-refund DEX_ADDRESS recipient (some 0x00))))
              true
            )
            true
          )
          ;; Clear MH status
          (var-set majority-holder-address none)
          (var-set locked-tokens u0)
          ;; Proceed with withdrawal (no threshold check, but still validates balance)
          ;; IMPORTANT: Rewards come ONLY from accumulated-trading-fees, not from sats-available-for-trading
          (var-set accumulated-trading-fees u0)
          ;; Update total SBTC balance tracking (contract pays out rewards from accumulated-trading-fees only)
          (var-set total-sbtc-balance (- (var-get total-sbtc-balance) fees-to-claim))
          ;; Derive sats-available-for-trading from total - accumulated (ensures it's always in sync)
          (var-set sats-available-for-trading (- (var-get total-sbtc-balance) (var-get accumulated-trading-fees)))
          ;; Track lifetime MH rewards paid out
          (var-set total-majority-holder-rewards-paid-out (+ (var-get total-majority-holder-rewards-paid-out) fees-to-claim))
          ;; Track per-user MH rewards
          (let ((current-mh-rewards (default-to u0 (map-get? mh-rewards-received {holder: recipient}))))
            (map-set mh-rewards-received {holder: recipient} (+ current-mh-rewards fees-to-claim))
          )
          (try! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token 
            transfer fees-to-claim DEX_ADDRESS recipient (some 0x00))))
          (ok fees-to-claim)
        )
        ;; NORMAL WITHDRAWAL - Regular MH (not MM)
        (let (
          (unlock-threshold (unwrap! (sats-needed-to-unlock) ERR_NOT_INITIALIZED)) ;; FEATURE 5: Get threshold
        )
          ;; FEATURE 6: Check threshold restriction
          (asserts! (>= fees-to-claim unlock-threshold) ERR_CANNOT_WITHDRAW_BELOW_THRESHOLD)
          ;; FEATURE 7: Track highest withdrawal (capped at 1M for threshold calculation)
          (let (
            (current-highest (var-get last-highest-withdrawal))
            (amount-for-threshold (if (> fees-to-claim MAX_UNLOCK_THRESHOLD) MAX_UNLOCK_THRESHOLD fees-to-claim))
            (new-highest (if (> amount-for-threshold current-highest) amount-for-threshold current-highest))
            (permanent-threshold (if (> fees-to-claim MAX_UNLOCK_THRESHOLD) MAX_UNLOCK_THRESHOLD (var-get unlock-threshold-permanent)))
          )
            (var-set last-highest-withdrawal new-highest)
            (var-set unlock-threshold-permanent permanent-threshold)
          )
          ;; Proceed with withdrawal
          ;; IMPORTANT: Rewards come ONLY from accumulated-trading-fees, not from sats-available-for-trading
          (var-set accumulated-trading-fees u0)
          ;; Update total SBTC balance tracking (contract pays out rewards from accumulated-trading-fees only)
          (var-set total-sbtc-balance (- (var-get total-sbtc-balance) fees-to-claim))
          ;; Derive sats-available-for-trading from total - accumulated (ensures it's always in sync)
          (var-set sats-available-for-trading (- (var-get total-sbtc-balance) (var-get accumulated-trading-fees)))
          ;; Track lifetime MH rewards paid out
          (var-set total-majority-holder-rewards-paid-out (+ (var-get total-majority-holder-rewards-paid-out) fees-to-claim))
          ;; Track per-user MH rewards
          (let ((current-mh-rewards (default-to u0 (map-get? mh-rewards-received {holder: majority-holder}))))
            (map-set mh-rewards-received {holder: majority-holder} (+ current-mh-rewards fees-to-claim))
          )
          (try! (as-contract (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token 
            transfer fees-to-claim DEX_ADDRESS majority-holder (some 0x00))))
          (ok fees-to-claim)
        )
      )
    )
  )
)

;; Quit being majority holder: Unlocks tokens (FEATURE 5: now requires threshold check)
(define-public (quit-being-majority-holder)
  (let (
    (current-majority (var-get majority-holder-address))
    (current-locked (var-get locked-tokens))
    (current-fees (var-get accumulated-trading-fees))
    (unlock-threshold (unwrap! (sats-needed-to-unlock) ERR_NOT_INITIALIZED)) ;; FEATURE 5: Use new threshold system
    (recipient tx-sender)  ;; Capture user address before as-contract
    (current-curve-tokens (default-to u0 (map-get? curve-tokens-bought {holder: tx-sender})))
  )
    (begin
      (asserts! (is-eq (var-get initialized) true) ERR_NOT_INITIALIZED)
      (asserts! (is-eq current-majority (some tx-sender)) ERR_UNAUTHORIZED)
      (asserts! (> current-locked u0) ERR_NOT_ENOUGH_TOKEN_BALANCE)
      ;; FEATURE 5: Check threshold before unlocking
      (asserts! (>= current-fees unlock-threshold) ERR_CANNOT_UNLOCK_BELOW_THRESHOLD)
      ;; Refund locked tokens
      (try! (as-contract (contract-call? 'SP1T0VY3DNXRVP6HBM75DFWW0199CR0X15PC1D81B.teiko-token-stxcity
        transfer current-locked DEX_ADDRESS recipient (some 0x00))))
      ;; Restore curve-tokens-bought (they can now sell their refunded tokens)
      (map-set curve-tokens-bought {holder: tx-sender} (+ current-curve-tokens current-locked))
      ;; Clear majority holder status
      (var-set majority-holder-address none)
      (var-set locked-tokens u0)
      (ok true)
    )
  )
)

;; ========================================
;; READ-ONLY FUNCTIONS
;; ========================================
(define-read-only (get-remaining-tokens-to-buy)
  (ok (/ (var-get token-balance) TOKEN_DECIMALS))
)

;; Look up how many tokens a specific user has bought and currently holds from the bonding curve (in human-readable format)
;; Returns the number of tokens the user currently holds that were bought from the curve (can be sold)
(define-read-only (get-user-current-tokens-bought (user principal))
  (ok (/ (default-to u0 (map-get? curve-tokens-bought {holder: user})) TOKEN_DECIMALS))
)

(define-read-only (get-market-maker-address)
  (ok (var-get market-manager-address))
)

(define-read-only (get-sats-available-for-trading)
  (ok (var-get sats-available-for-trading))
)

(define-read-only (get-total-token-supply)
  (ok (/ (var-get market-maker-deposit) TOKEN_DECIMALS))
)

;; Returns tokens required to become market maker (in human-readable format)
;; FEATURE 1: Updated to reflect 10k increment
(define-read-only (get-tokens-required-to-become-maker)
  (let (
    (current-deposit (var-get market-maker-deposit))
  )
    (if (is-eq current-deposit u0)
      ;; No market exists yet
      (ok (/ MIN_INITIAL_DEPOSIT TOKEN_DECIMALS))
      ;; Market exists: current deposit + 10k (FEATURE 1)
      (ok (/ (+ current-deposit OVERTAKE_INCREMENT) TOKEN_DECIMALS))
    )
  )
)

;; Returns Current Majority holder rewards
(define-read-only (get-current-majority-holder-rewards)
  (ok (var-get accumulated-trading-fees))
)

;; Returns total SBTC balance tracked by contract (for debugging balance mismatches)
;; Should equal: sats-available-for-trading + accumulated-trading-fees
;; Can be compared against actual contract SBTC balance to identify discrepancies
(define-read-only (get-total-sbtc-balance)
  (ok (var-get total-sbtc-balance))
)

(define-read-only (get-current-majority-holder)
  (ok (var-get majority-holder-address))
)

(define-read-only (get-current-tokens-locked)
  (ok (/ (var-get locked-tokens) TOKEN_DECIMALS))
)

;; Returns how many tokens you need to lock to become majority holder (in human-readable format)
(define-read-only (get-tokens-needed-to-become-majority-holder)
  (let (
    (current-majority (var-get majority-holder-address))
    (current-locked (var-get locked-tokens))
  )
    (if (is-none current-majority)
      ;; No majority holder: Need to lock 2k tokens
      (ok (/ LOCK_INCREMENT TOKEN_DECIMALS))
      ;; Majority holder exists: Need to lock current + 2k
      (ok (/ (+ current-locked LOCK_INCREMENT) TOKEN_DECIMALS))
    )
  )
)

;; Returns sats needed to unlock (threshold system - 1M cap)
(define-read-only (sats-needed-to-unlock)
  (let (
    (permanent-threshold (var-get unlock-threshold-permanent))
    (highest-withdrawal (var-get last-highest-withdrawal))
  )
    (if (> permanent-threshold u0)
      ;; Permanent threshold is set (someone withdrew > 1M)
      (ok permanent-threshold)
      ;; No permanent threshold, use dynamic: max(highest-withdrawal, 1500)
      (ok (if (> highest-withdrawal MIN_UNLOCK_THRESHOLD)
            highest-withdrawal
            MIN_UNLOCK_THRESHOLD))
    )
  )
)

;; Returns last highest withdrawal amount
(define-read-only (get-last-highest-withdrawal)
  (ok (var-get last-highest-withdrawal))
)

;; Returns permanent unlock threshold (0 if not set)
(define-read-only (get-max-unlock-sats-threshold)
  (ok (var-get unlock-threshold-permanent))
)

;; ========================================
;; PROFIT TRACKING FUNCTIONS
;; ========================================
;; Returns estimated satoshis needed to buy tokens (in thousands) at current price
;; Uses same formula as actual trades (remaining + virtual) to ensure estimation matches actual cost
;; token-amount-thousands: Amount in thousands (1 = 1k tokens, 5 = 5k tokens, 10 = 10k tokens, etc.)
(define-read-only (get-estimated-cost-for-tokens (token-amount-thousands uint))
  (let (
    (tokens-out (* token-amount-thousands u1000 TOKEN_DECIMALS)) ;; Convert thousands to raw
    (current-sbtc-balance (+ (var-get sats-available-for-trading) (var-get virtual-sbtc-amount)))
    (current-token-balance (var-get token-balance))
  )
    (if (or (is-eq current-token-balance u0) (< current-token-balance tokens-out))
      (ok u0)
      (let (
        (k (* current-token-balance current-sbtc-balance))
        (new-token-balance (- current-token-balance tokens-out))
        (new-sbtc-balance (/ k new-token-balance))
        (net-sbtc-needed (- new-sbtc-balance current-sbtc-balance))
      )
        (ok net-sbtc-needed)
      )
    )
  )
)

;; Returns current position sats a user would receive if they sold all tokens now (after 21% fees: 6% MM + 15% MH, returns 0 if negative)
(define-read-only (get-user-current-value-of-tokens-in-sats (user principal))
  (let (
    (user-curve-tokens (default-to u0 (map-get? curve-tokens-bought {holder: user})))
  )
    (if (is-eq user-curve-tokens u0)
      (ok u0)
      (let (
        (available-sbtc (var-get sats-available-for-trading))
        (current-sbtc-balance (+ available-sbtc (var-get virtual-sbtc-amount)))
        (current-token-balance (var-get token-balance))
        (k (* current-token-balance current-sbtc-balance))
        (new-token-balance (+ current-token-balance user-curve-tokens))
        (new-sbtc-balance (/ k new-token-balance))
        (sbtc-out (- current-sbtc-balance new-sbtc-balance))
        ;; Cap sbtc-out to available real SBTC before calculating fees (EXACT same as sell function)
        (capped-sbtc-out (if (>= sbtc-out available-sbtc) available-sbtc sbtc-out))
        (mm-fee (/ (* capped-sbtc-out u600) u10000)) ;; 6% fee to market maker
        (mh-fee (/ (* capped-sbtc-out u1500) u10000)) ;; 15% fee to majority holder pot
        (sbtc-after-fees (- capped-sbtc-out (+ mm-fee mh-fee))) ;; Net SBTC after 21% fees
      )
        ;; Return exact amount that sell function will pay (after fees, capped to available)
        (ok (if (> sbtc-after-fees u0) sbtc-after-fees u0))
      )
    )
  )
)

;; ========================================
;; LIFETIME PROFIT TRACKING FUNCTIONS
;; ========================================
;; Returns lifetime total fees withdrawn by majority holders (in sats)
(define-read-only (get-lifetime-majority-holder-rewards-paid-out)
  (ok (var-get total-majority-holder-rewards-paid-out))
)

;; Returns lifetime total fees paid to market makers (in sats)
(define-read-only (get-lifetime-market-maker-fees-paid)
  (ok (var-get total-market-maker-fees-paid))
)

;; Returns lifetime total realized profit by all traders (received - invested, returns 0 if negative)
(define-read-only (get-total-realized-profit-by-traders)
  (let (
    (total-invested (var-get total-sbtc-invested-by-traders))
    (total-received (var-get total-sbtc-received-by-traders))
    (profit (- total-received total-invested))
  )
    (ok (if (> profit u0) profit u0))
  )
)

;; Returns lifetime total rewards received by all users (traders + MH + MM)
(define-read-only (get-total-rewards-received-by-all-users)
  (let (
    (traders-received (var-get total-sbtc-received-by-traders))
    (mh-rewards (var-get total-majority-holder-rewards-paid-out))
    (mm-fees (var-get total-market-maker-fees-paid))
    (total-rewards (+ traders-received (+ mh-rewards mm-fees)))
  )
    (ok total-rewards)
  )
)

;; Returns lifetime total SBTC invested by all traders (in sats)
(define-read-only (get-total-sats-invested-by-all-users)
  (ok (var-get total-sbtc-invested-by-traders))
)

;; Returns lifetime realized profit for a specific user (sbtc-received - sbtc-invested, returns 0 if negative)
;; Realized profit = actual profit from completed trades (sells minus buys)
(define-read-only (get-user-lifetime-realized-profit (user principal))
  (let (
    (invested (default-to u0 (map-get? sbtc-invested {holder: user})))
    (received (default-to u0 (map-get? sbtc-received {holder: user})))
    (profit (- received invested))
  )
    (ok (if (> profit u0) profit u0))
  )
)

;; Returns current position unrealized profit for a specific user (current holdings value - current position invested)
;; Uses current-sats-invested (resets to 0 on sell-all) for current position tracking
;; Unrealized profit = profit they would make if they sold all current tokens now
(define-read-only (get-user-current-unrealized-profit (user principal))
  (let (
    (invested (default-to u0 (map-get? current-sats-invested {holder: user})))
    (user-curve-tokens (default-to u0 (map-get? curve-tokens-bought {holder: user})))
  )
    (if (is-eq user-curve-tokens u0)
      ;; No tokens held: unrealized profit = 0 (no holdings)
      (ok u0)
      ;; Has tokens: calculate current holdings value - current position invested
      (let (
        (current-sbtc-balance (+ (var-get sats-available-for-trading) (var-get virtual-sbtc-amount)))
        (current-token-balance (var-get token-balance))
        (k (* current-token-balance current-sbtc-balance))
        (new-token-balance (+ current-token-balance user-curve-tokens))
        (new-sbtc-balance (/ k new-token-balance))
        (sbtc-out (- current-sbtc-balance new-sbtc-balance))
        (mm-fee (/ (* sbtc-out u600) u10000)) ;; 6% fee to market maker
        (mh-fee (/ (* sbtc-out u1500) u10000)) ;; 15% fee to majority holder pot
        (sbtc-after-fees (- sbtc-out (+ mm-fee mh-fee))) ;; Net SBTC after 21% fees
        (current-holdings-value sbtc-after-fees)
        (unrealized-profit (- current-holdings-value invested))
      )
        (ok (if (> unrealized-profit u0) unrealized-profit u0))
      )
    )
  )
)

;; ========================================
;; ADDITIONAL STATISTICS FUNCTIONS
;; ========================================
;; Returns lifetime total SBTC invested by a specific user (in sats, includes fees) - lifetime, never resets
(define-read-only (get-user-lifetime-sbtc-invested (user principal))
  (ok (default-to u0 (map-get? sbtc-invested {holder: user})))
)

;; Returns current position SBTC invested by a specific user (in sats, includes fees) - resets to 0 on sell-all
;; Use this with get-user-current-tokens-bought to calculate average cost per token: current-sats-invested / tokens-held
(define-read-only (get-user-current-sats-invested (user principal))
  (ok (default-to u0 (map-get? current-sats-invested {holder: user})))
)

;; Returns lifetime total SBTC received by a specific user from sells (in sats)
(define-read-only (get-user-lifetime-sbtc-received (user principal))
  (ok (default-to u0 (map-get? sbtc-received {holder: user})))
)

;; Returns lifetime MH rewards received by a specific user (in sats)
(define-read-only (get-user-lifetime-majority-holder-rewards-received (user principal))
  (ok (default-to u0 (map-get? mh-rewards-received {holder: user})))
)

;; Returns lifetime MM fees earned by a specific user (in sats)
(define-read-only (get-user-lifetime-market-maker-fees-earned (user principal))
  (ok (default-to u0 (map-get? mm-fees-earned {holder: user})))
)

```
