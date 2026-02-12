;; StackPulse Fee Vault V2
;; Handles subscription payments, fee collection, and treasury management
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

;; Subscription prices in microSTX
(define-constant PRICE-FREE u0)
(define-constant PRICE-BASIC u5000000)       ;; 5 STX
(define-constant PRICE-PRO u15000000)        ;; 15 STX  
(define-constant PRICE-PREMIUM u45000000)    ;; 45 STX

;; Platform fee percentage (10%)
(define-constant PLATFORM-FEE-BPS u1000)     ;; 10% in basis points (1000/10000)
(define-constant REFERRAL-BONUS-BPS u500)    ;; 5% referral bonus

;; ============================================
;; DATA STORAGE
;; ============================================

(define-data-var total-collected uint u0)
(define-data-var total-fees uint u0)
(define-data-var total-subscriptions uint u0)
(define-data-var contract-balance uint u0)

;; Track revenue by tier
(define-map tier-revenue uint uint)

;; Track user payments
(define-map user-payments principal 
  {
    total-paid: uint,
    last-payment: uint,
    subscription-count: uint
  }
)

;; Referral tracking
(define-map referral-earnings principal uint)
(define-map referrer-of principal principal)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

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

(define-read-only (get-vault-stats)
  {
    total-collected: (var-get total-collected),
    total-fees: (var-get total-fees),
    total-subscriptions: (var-get total-subscriptions),
    contract-balance: (var-get contract-balance),
    tier-0-revenue: (get-tier-revenue u0),
    tier-1-revenue: (get-tier-revenue u1),
    tier-2-revenue: (get-tier-revenue u2),
    tier-3-revenue: (get-tier-revenue u3)
  }
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
        { total-paid: u0, last-payment: u0, subscription-count: u0 }
        (map-get? user-payments caller)))
    )
    ;; Validate tier
    (asserts! (<= tier u3) ERR-INVALID-TIER)
    
    ;; Only transfer if not free tier
    (if (> price u0)
      (begin
        ;; Transfer STX to this contract
        (try! (stx-transfer? price caller (as-contract tx-sender)))
        
        ;; Handle referral bonus if referrer exists
        (match referrer
          ref-addr (if (and (not (is-eq ref-addr caller)) (> price u0))
            (let
              (
                (referral-bonus (/ (* price REFERRAL-BONUS-BPS) u10000))
                (current-earnings (get-referral-earnings ref-addr))
              )
              ;; Track referral
              (map-set referrer-of caller ref-addr)
              (map-set referral-earnings ref-addr (+ current-earnings referral-bonus))
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
    
    ;; Update user payments
    (map-set user-payments caller {
      total-paid: (+ (get total-paid user-data) price),
      last-payment: block-height,
      subscription-count: (+ (get subscription-count user-data) u1)
    })
    
    ;; Update subscription count
    (var-set total-subscriptions (+ (var-get total-subscriptions) u1))
    
    (print {
      event: "fee-collected",
      user: caller,
      tier: tier,
      amount: price,
      referrer: referrer,
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
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Transfer fee
    (try! (stx-transfer? fee-amount caller (as-contract tx-sender)))
    
    ;; Update tracking
    (var-set total-fees (+ (var-get total-fees) fee-amount))
    (var-set contract-balance (+ (var-get contract-balance) fee-amount))
    
    (print {
      event: "platform-fee-collected",
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
    (asserts! (> earnings u0) ERR-INSUFFICIENT-BALANCE)
    
    ;; Transfer earnings
    (try! (as-contract (stx-transfer? earnings tx-sender caller)))
    
    ;; Reset earnings
    (map-set referral-earnings caller u0)
    (var-set contract-balance (- (var-get contract-balance) earnings))
    
    (print {
      event: "referral-withdrawal",
      user: caller,
      amount: earnings,
      block: block-height
    })
    
    (ok earnings)
  )
)

;; Admin: Withdraw to treasury
(define-public (withdraw-to-treasury (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= amount (var-get contract-balance)) ERR-INSUFFICIENT-BALANCE)
    
    ;; Transfer to treasury
    (try! (as-contract (stx-transfer? amount tx-sender TREASURY-ADDRESS)))
    
    ;; Update balance
    (var-set contract-balance (- (var-get contract-balance) amount))
    
    (print {
      event: "treasury-withdrawal",
      amount: amount,
      block: block-height
    })
    
    (ok amount)
  )
)
