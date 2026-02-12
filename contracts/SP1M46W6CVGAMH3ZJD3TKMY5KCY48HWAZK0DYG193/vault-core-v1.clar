;; ========================================
;; VAULTAYIELD - CORE VAULT CONTRACT
;; ========================================
;; Bitcoin-native yield vault for STX stacking
;; Users deposit STX, earn BTC rewards automatically

;; ========================================
;; CONSTANTS
;; ========================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant PRECISION u1000000) ;; 6 decimal precision for calculations

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ZERO-AMOUNT (err u101))
(define-constant ERR-INSUFFICIENT-SHARES (err u102))
(define-constant ERR-CALCULATION-ERROR (err u103))
(define-constant ERR-CONTRACT-PAUSED (err u104))
(define-constant ERR-INSUFFICIENT-BALANCE (err u105))
(define-constant ERR-INVALID-FEE-RATE (err u106))

;; Fee constraints
(define-constant MAX-FEE-RATE u200) ;; 2% maximum (200 basis points)
(define-constant DEFAULT-WITHDRAWAL-FEE u50) ;; 0.5% (50 basis points)

;; ========================================
;; DATA VARIABLES
;; ========================================

(define-data-var total-shares uint u0)
(define-data-var total-assets uint u0)
(define-data-var withdrawal-fee-rate uint DEFAULT-WITHDRAWAL-FEE)
(define-data-var fee-balance uint u0)
(define-data-var contract-paused bool false)

;; Phase 2: PoX Stacking Integration
(define-data-var stacking-strategy-contract (optional principal) none)
(define-data-var stacking-enabled bool false)
(define-data-var min-stacking-threshold uint u100000000000000) ;; 100K STX minimum

;; Phase 3: Will add harvest-manager and compound-engine references

;; ========================================
;; DATA MAPS
;; ========================================

(define-map user-shares principal uint)

;; ========================================
;; PRIVATE FUNCTIONS
;; ========================================

(define-private (calculate-shares-to-mint (deposit-amount uint))
  ;; Calculate shares based on current vault state
  ;; Formula: shares = (deposit-amount * total-shares) / total-assets
  ;; For first deposit: shares = deposit-amount (1:1 ratio)
  (let
    (
      (current-total-shares (var-get total-shares))
      (current-total-assets (var-get total-assets))
    )
    (if (is-eq current-total-shares u0)
      ;; First deposit: 1:1 ratio
      (ok deposit-amount)
      ;; Subsequent deposits: proportional to share price
      (ok (/ (* deposit-amount current-total-shares) current-total-assets))
    )
  )
)

(define-private (calculate-stx-to-return (shares-to-burn uint))
  ;; Calculate STX to return based on share price
  ;; Formula: stx-amount = (shares * total-assets) / total-shares
  (let
    (
      (current-total-shares (var-get total-shares))
      (current-total-assets (var-get total-assets))
    )
    (if (is-eq current-total-shares u0)
      ERR-CALCULATION-ERROR
      (ok (/ (* shares-to-burn current-total-assets) current-total-shares))
    )
  )
)

(define-private (apply-withdrawal-fee (amount uint))
  ;; Calculate withdrawal fee and net amount
  ;; Returns: { fee: uint, net-amount: uint }
  (let
    (
      (fee-rate (var-get withdrawal-fee-rate))
      (fee-amount (/ (* amount fee-rate) u10000))
      (net-amount (- amount fee-amount))
    )
    { fee: fee-amount, net-amount: net-amount }
  )
)

;; ========================================
;; PUBLIC FUNCTIONS - USER INTERACTIONS
;; ========================================

(define-public (deposit (amount uint))
  ;; Accept STX from user and mint vault shares
  (let
    (
      (shares-to-mint (unwrap! (calculate-shares-to-mint amount) ERR-CALCULATION-ERROR))
      (sender tx-sender)
    )
    ;; Validation
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    
    ;; Transfer STX from user to contract
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    
    ;; Update user shares
    (map-set user-shares 
      sender 
      (+ (default-to u0 (map-get? user-shares sender)) shares-to-mint)
    )
    
    ;; Update vault state
    (var-set total-shares (+ (var-get total-shares) shares-to-mint))
    (var-set total-assets (+ (var-get total-assets) amount))
    
    ;; Emit event (using print for Clarity)
    (print {
      event: "deposit",
      user: sender,
      amount: amount,
      shares-minted: shares-to-mint,
      timestamp: block-height
    })
    
    (ok shares-to-mint)
  )
)

(define-public (deposit-with-stacking (amount uint) (lock-cycles uint))
  ;; Deposit STX and automatically delegate to stacking
  ;; Phase 2: Manual stacking delegation
  ;; Phase 3: Automatic stacking based on threshold
  (let
    (
      (shares-to-mint (unwrap! (calculate-shares-to-mint amount) ERR-CALCULATION-ERROR))
      (sender tx-sender)
      (current-shares (default-to u0 (map-get? user-shares sender)))
      (stacking-enabled-flag (var-get stacking-enabled))
      (stacking-contract (var-get stacking-strategy-contract))
    )
    ;; Validation
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! stacking-enabled-flag ERR-NOT-AUTHORIZED)
    (asserts! (is-some stacking-contract) ERR-NOT-AUTHORIZED)
    
    ;; Transfer STX from user to contract
    (try! (stx-transfer? amount sender (as-contract tx-sender)))
    
    ;; Mint shares for user
    (map-set user-shares sender (+ current-shares shares-to-mint))
    
    ;; Update vault totals
    (var-set total-shares (+ (var-get total-shares) shares-to-mint))
    (var-set total-assets (+ (var-get total-assets) amount))
    
    ;; Delegate to stacking strategy if threshold met
    (if (>= (var-get total-assets) (var-get min-stacking-threshold))
      (begin
        ;; TODO: Call stacking-strategy contract
        ;; (try! (as-contract (contract-call? 
        ;;   .stacking-strategy delegate-vault-stx amount lock-cycles)))
        (print { event: "stacking-triggered", amount: amount, cycles: lock-cycles })
        true
      )
      (begin
        (print { event: "below-threshold", current: (var-get total-assets), threshold: (var-get min-stacking-threshold) })
        true
      )
    )
    
    ;; Emit deposit event
    (print { event: "deposit-with-stacking", user: sender, amount: amount, shares: shares-to-mint, cycles: lock-cycles })
    
    (ok shares-to-mint)
  )
)

(define-public (withdraw (shares uint))
  ;; Burn vault shares and return STX to user
  (let
    (
      (sender tx-sender)
      (user-balance (default-to u0 (map-get? user-shares sender)))
      (gross-stx-amount (unwrap! (calculate-stx-to-return shares) ERR-CALCULATION-ERROR))
      (fee-calculation (apply-withdrawal-fee gross-stx-amount))
      (fee-amount (get fee fee-calculation))
      (net-stx-amount (get net-amount fee-calculation))
    )
    ;; Validation
    (asserts! (not (var-get contract-paused)) ERR-NOT-AUTHORIZED)
    (asserts! (> shares u0) ERR-ZERO-AMOUNT)
    (asserts! (>= user-balance shares) ERR-INSUFFICIENT-BALANCE)
    
    ;; Update user shares
    (map-set user-shares sender (- user-balance shares))
    
    ;; Update vault state
    (var-set total-shares (- (var-get total-shares) shares))
    (var-set total-assets (- (var-get total-assets) gross-stx-amount))
    (var-set fee-balance (+ (var-get fee-balance) fee-amount))
    
    ;; Transfer STX back to user
    (try! (as-contract (stx-transfer? net-stx-amount tx-sender sender)))
    
    ;; Emit event
    (print {
      event: "withdrawal",
      user: sender,
      shares-burned: shares,
      stx-returned: net-stx-amount,
      fee-collected: fee-amount,
      timestamp: block-height
    })
    
    (ok net-stx-amount)
  )
)

;; ========================================
;; PUBLIC FUNCTIONS - ADMIN ONLY
;; ========================================

(define-public (set-withdrawal-fee (new-rate uint))
  ;; Update withdrawal fee rate (only owner)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-rate MAX-FEE-RATE) ERR-INVALID-FEE-RATE)
    (var-set withdrawal-fee-rate new-rate)
    (ok true)
  )
)

(define-public (collect-fees (recipient principal))
  ;; Withdraw accumulated fees (only owner)
  (let
    (
      (accumulated-fees (var-get fee-balance))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> accumulated-fees u0) ERR-ZERO-AMOUNT)
    
    ;; Reset fee balance
    (var-set fee-balance u0)
    
    ;; Transfer fees
    (try! (as-contract (stx-transfer? accumulated-fees tx-sender recipient)))
    (ok accumulated-fees)
  )
)

;; ========================================
;; PUBLIC FUNCTIONS - PHASE 2 ADMIN CONFIG
;; ========================================

(define-public (set-stacking-strategy (strategy-address principal))
  ;; Set authorized stacking strategy contract
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set stacking-strategy-contract (some strategy-address))
    (ok true)
  )
)

;; Phase 3: Will add set-harvest-manager and set-compound-engine functions

(define-public (enable-stacking)
  ;; Enable stacking feature
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set stacking-enabled true)
    (ok true)
  )
)

(define-public (set-stacking-threshold (threshold uint))
  ;; Update minimum STX threshold for stacking
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> threshold u0) ERR-ZERO-AMOUNT)
    (var-set min-stacking-threshold threshold)
    (ok true)
  )
)

(define-public (pause-contract)
  ;; Emergency pause (only owner)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set contract-paused true)
    (ok true)
  )
)

(define-public (unpause-contract)
  ;; Resume operations (only owner)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set contract-paused false)
    (ok true)
  )
)

;; ========================================
;; READ-ONLY FUNCTIONS
;; ========================================

(define-read-only (get-share-price)
  ;; Calculate current price per share
  ;; Returns price with PRECISION decimal places
  (let
    (
      (current-total-shares (var-get total-shares))
      (current-total-assets (var-get total-assets))
    )
    (if (is-eq current-total-shares u0)
      PRECISION ;; 1.0 (1:1 for first deposit)
      (/ (* current-total-assets PRECISION) current-total-shares)
    )
  )
)

(define-read-only (get-user-shares (user principal))
  ;; Return user's vault share balance
  (default-to u0 (map-get? user-shares user))
)

(define-read-only (get-user-stx-value (user principal))
  ;; Calculate user's STX value based on current shares
  (let
    (
      (shares (get-user-shares user))
      (share-price (get-share-price))
    )
    (/ (* shares share-price) PRECISION)
  )
)

(define-read-only (get-total-assets)
  ;; Return total STX held by vault
  (var-get total-assets)
)

(define-read-only (get-total-shares)
  ;; Return total vault shares issued
  (var-get total-shares)
)

(define-read-only (get-withdrawal-fee-rate)
  ;; Return current withdrawal fee rate
  (var-get withdrawal-fee-rate)
)

(define-read-only (get-accumulated-fees)
  ;; Return total fees collected
  (var-get fee-balance)
)

(define-read-only (is-paused)
  ;; Check if contract is paused
  (var-get contract-paused)
)

(define-read-only (get-contract-owner)
  ;; Return contract owner address
  CONTRACT-OWNER
)
