;; StackPulse Fee Vault V3
;; Upgrades from V2:
;; - Enhanced error handling
;; - Optimized gas usage
;; - Better revenue tracking per tier
;; - Improved referral system
;; - Enhanced event logging for chainhooks
;;
;; Features:
;; - Subscription fee collection
;; - Revenue tracking per tier
;; - Withdrawal to treasury
;; - Referral bonus tracking

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant TREASURY-ADDRESS tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-AMOUNT (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))
(define-constant ERR-INVALID-TIER (err u103))
(define-constant ERR-ZERO-AMOUNT (err u104))
(define-constant ERR-SELF-REFERRAL (err u105))
(define-constant ERR-NO-EARNINGS (err u106))

;; Subscription prices in microSTX
(define-constant PRICE-FREE u0)
(define-constant PRICE-BASIC u5000000)       ;; 5 STX
(define-constant PRICE-PRO u15000000)        ;; 15 STX  
(define-constant PRICE-PREMIUM u45000000)    ;; 45 STX

;; Platform fee percentage (10%)
(define-constant PLATFORM-FEE-BPS u1000)     ;; 10% in basis points (1000/10000)
(define-constant REFERRAL-BONUS-BPS u500)    ;; 5% referral bonus
(define-constant MAX-TIER u3)

;; ============================================
;; DATA STORAGE
;; ============================================

(define-data-var total-collected uint u0)
(define-data-var total-fees uint u0)
(define-data-var total-subscriptions uint u0)
(define-data-var total-referral-paid uint u0)  ;; V3: Track total referral payouts
(define-data-var contract-balance uint u0)
(define-data-var contract-version (string-ascii 8) "v3.0.0")

;; Track revenue by tier
(define-map tier-revenue uint uint)

;; Track user payments with V3 enhanced data
(define-map user-payments principal 
  {
    total-paid: uint,
    last-payment: uint,
    subscription-count: uint,
    current-tier: uint       ;; V3: Track current tier
  }
)

;; Referral tracking
(define-map referral-earnings principal uint)
(define-map referrer-of principal principal)
(define-map referral-count principal uint)  ;; V3: Count of referrals per user

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-version)
  (var-get contract-version)
)

(define-read-only (get-subscription-price (tier uint))
  (if (is-eq tier u0) PRICE-FREE
    (if (is-eq tier u1) PRICE-BASIC
      (if (is-eq tier u2) PRICE-PRO
        (if (is-eq tier u3) PRICE-PREMIUM
          u0))))
)

(define-read-only (get-tier-revenue (tier uint))
  (default-to u0 (map-get? tier-revenue tier))
)

(define-read-only (get-user-payments (user principal))
  (map-get? user-payments user)
)

(define-read-only (get-referral-earnings (referrer principal))
  (default-to u0 (map-get? referral-earnings referrer))
)

(define-read-only (get-referral-count (referrer principal))
  (default-to u0 (map-get? referral-count referrer))
)

(define-read-only (get-referrer (user principal))
  (map-get? referrer-of user)
)

(define-read-only (get-vault-stats)
  {
    total-collected: (var-get total-collected),
    total-fees: (var-get total-fees),
    total-subscriptions: (var-get total-subscriptions),
    total-referral-paid: (var-get total-referral-paid),
    contract-balance: (var-get contract-balance),
    tier-0-revenue: (get-tier-revenue u0),
    tier-1-revenue: (get-tier-revenue u1),
    tier-2-revenue: (get-tier-revenue u2),
    tier-3-revenue: (get-tier-revenue u3),
    version: (var-get contract-version)
  }
)

;; ============================================
;; PRIVATE HELPER FUNCTIONS
;; ============================================

;; V3: Validate tier
(define-private (is-valid-tier (tier uint))
  (<= tier MAX-TIER)
)

;; V3: Calculate referral bonus
(define-private (calculate-referral-bonus (amount uint))
  (/ (* amount REFERRAL-BONUS-BPS) u10000)
)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; Collect subscription fee
(define-public (collect-subscription-fee (tier uint) (referrer (optional principal)))
  (let
    (
      (caller tx-sender)
      (price (get-subscription-price tier))
      (current-tier-revenue (get-tier-revenue tier))
      (user-data (default-to 
        { total-paid: u0, last-payment: u0, subscription-count: u0, current-tier: u0 }
        (map-get? user-payments caller)))
    )
    ;; V3: Enhanced validation
    (asserts! (is-valid-tier tier) ERR-INVALID-TIER)
    
    ;; Only transfer if not free tier
    (if (> price u0)
      (begin
        ;; Transfer STX to this contract
        (try! (stx-transfer? price caller (as-contract tx-sender)))
        
        ;; V3: Enhanced referral handling
        (match referrer
          ref-addr 
            (if (and (not (is-eq ref-addr caller)) (> price u0))
              (let
                (
                  (referral-bonus (calculate-referral-bonus price))
                  (current-earnings (get-referral-earnings ref-addr))
                  (current-ref-count (get-referral-count ref-addr))
                )
                ;; Track referral
                (map-set referrer-of caller ref-addr)
                (map-set referral-earnings ref-addr (+ current-earnings referral-bonus))
                (map-set referral-count ref-addr (+ current-ref-count u1))
                true
              )
              false)
          false)
        
        ;; Update balances
        (var-set total-collected (+ (var-get total-collected) price))
        (var-set contract-balance (+ (var-get contract-balance) price))
        
        true
      )
      true)
    
    ;; Update tier revenue
    (map-set tier-revenue tier (+ current-tier-revenue price))
    
    ;; V3: Update user payments with current tier
    (map-set user-payments caller {
      total-paid: (+ (get total-paid user-data) price),
      last-payment: block-height,
      subscription-count: (+ (get subscription-count user-data) u1),
      current-tier: tier
    })
    
    ;; Update subscription count
    (var-set total-subscriptions (+ (var-get total-subscriptions) u1))
    
    (print {
      event: "fee-collected",
      version: "v3",
      user: caller,
      tier: tier,
      amount: price,
      referrer: referrer,
      subscription-number: (+ (get subscription-count user-data) u1),
      block: block-height
    })
    
    (ok price)
  )
)

;; Collect platform fee (called on alert triggers, etc.)
(define-public (collect-platform-fee (amount uint) (fee-type (string-ascii 32)))
  (let
    (
      (caller tx-sender)
      (fee-amount (/ (* amount PLATFORM-FEE-BPS) u10000))
    )
    ;; V3: Enhanced validation
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (> fee-amount u0) ERR-INVALID-AMOUNT)
    
    ;; Transfer fee
    (try! (stx-transfer? fee-amount caller (as-contract tx-sender)))
    
    ;; Update tracking
    (var-set total-fees (+ (var-get total-fees) fee-amount))
    (var-set contract-balance (+ (var-get contract-balance) fee-amount))
    
    (print {
      event: "platform-fee-collected",
      version: "v3",
      user: caller,
      fee-type: fee-type,
      amount: fee-amount,
      block: block-height
    })
    
    (ok fee-amount)
  )
)

;; Withdraw referral earnings
(define-public (withdraw-referral-earnings)
  (let
    (
      (caller tx-sender)
      (earnings (get-referral-earnings caller))
    )
    ;; V3: Better error message
    (asserts! (> earnings u0) ERR-NO-EARNINGS)
    (asserts! (<= earnings (var-get contract-balance)) ERR-INSUFFICIENT-BALANCE)
    
    ;; Transfer earnings
    (try! (as-contract (stx-transfer? earnings tx-sender caller)))
    
    ;; Reset earnings and update balances
    (map-set referral-earnings caller u0)
    (var-set contract-balance (- (var-get contract-balance) earnings))
    (var-set total-referral-paid (+ (var-get total-referral-paid) earnings))
    
    (print {
      event: "referral-withdrawal",
      version: "v3",
      user: caller,
      amount: earnings,
      block: block-height
    })
    
    (ok earnings)
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

;; Admin: Withdraw to treasury
(define-public (withdraw-to-treasury (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> amount u0) ERR-ZERO-AMOUNT)
    (asserts! (<= amount (var-get contract-balance)) ERR-INSUFFICIENT-BALANCE)
    
    ;; Transfer to treasury
    (try! (as-contract (stx-transfer? amount tx-sender TREASURY-ADDRESS)))
    
    ;; Update balance
    (var-set contract-balance (- (var-get contract-balance) amount))
    
    (print {
      event: "treasury-withdrawal",
      version: "v3",
      amount: amount,
      treasury: TREASURY-ADDRESS,
      remaining-balance: (- (var-get contract-balance) amount),
      block: block-height
    })
    
    (ok amount)
  )
)

;; V3: Admin emergency withdrawal (all funds)
(define-public (emergency-withdraw)
  (let
    (
      (balance (var-get contract-balance))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> balance u0) ERR-ZERO-AMOUNT)
    
    ;; Transfer all to treasury
    (try! (as-contract (stx-transfer? balance tx-sender TREASURY-ADDRESS)))
    
    ;; Reset balance
    (var-set contract-balance u0)
    
    (print {
      event: "emergency-withdrawal",
      version: "v3",
      amount: balance,
      treasury: TREASURY-ADDRESS,
      block: block-height
    })
    
    (ok balance)
  )
)
