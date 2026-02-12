---
title: "Trait stackpulse-registry"
draft: true
---
```
;; StackPulse Registry Contract
;; User registration, subscription tiers, and profile management
;; Built with Clarity 4 features for Stacks Builder Challenge

;; ============================================
;; CONSTANTS & ERRORS
;; ============================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ALREADY-REGISTERED (err u101))
(define-constant ERR-NOT-REGISTERED (err u102))
(define-constant ERR-INVALID-TIER (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))
(define-constant ERR-SUBSCRIPTION-EXPIRED (err u105))
(define-constant ERR-INVALID-INPUT (err u106))

;; Subscription tiers (in microSTX)
(define-constant TIER-FREE u0)
(define-constant TIER-BASIC u1)
(define-constant TIER-PRO u2)
(define-constant TIER-ENTERPRISE u3)

(define-constant PRICE-BASIC u5000000)      ;; 5 STX
(define-constant PRICE-PRO u15000000)       ;; 15 STX
(define-constant PRICE-ENTERPRISE u50000000) ;; 50 STX

(define-constant SUBSCRIPTION-DURATION u4320) ;; ~30 days in blocks

;; ============================================
;; DATA VARIABLES
;; ============================================

(define-data-var total-users uint u0)
(define-data-var total-revenue uint u0)
(define-data-var fee-vault-principal principal 'ST1PQHQKV0RJXZFY1DGX8MNSNYVE3VGZJSRTPGZGM)

;; ============================================
;; DATA MAPS
;; ============================================

(define-map users
  principal
  {
    registered-at: uint,
    tier: uint,
    subscription-expires: uint,
    alerts-created: uint,
    alerts-triggered: uint,
    total-spent: uint,
    referrer: (optional principal),
    username: (string-ascii 32),
    is-active: bool
  }
)

(define-map usernames
  (string-ascii 32)
  principal
)

(define-map tier-limits
  uint
  {
    max-alerts: uint,
    webhook-enabled: bool,
    priority-processing: bool,
    custom-filters: bool
  }
)

;; ============================================
;; INITIALIZATION - Using Clarity 4 begin in data-var
;; ============================================

;; Initialize tier limits
(map-set tier-limits TIER-FREE 
  { max-alerts: u3, webhook-enabled: false, priority-processing: false, custom-filters: false })
(map-set tier-limits TIER-BASIC 
  { max-alerts: u10, webhook-enabled: true, priority-processing: false, custom-filters: false })
(map-set tier-limits TIER-PRO 
  { max-alerts: u50, webhook-enabled: true, priority-processing: true, custom-filters: true })
(map-set tier-limits TIER-ENTERPRISE 
  { max-alerts: u500, webhook-enabled: true, priority-processing: true, custom-filters: true })

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

;; Get user profile - Using Clarity 4 enhanced optional handling
(define-read-only (get-user (user principal))
  (map-get? users user)
)

;; Check if user is registered
(define-read-only (is-registered (user principal))
  (is-some (map-get? users user))
)

;; Get username owner
(define-read-only (get-username-owner (username (string-ascii 32)))
  (map-get? usernames username)
)

;; Check if subscription is active - Using Clarity 4 stacks-block-height
(define-read-only (is-subscription-active (user principal))
  (match (map-get? users user)
    user-data (>= (get subscription-expires user-data) stacks-block-height)
    false
  )
)

;; Get user tier
(define-read-only (get-user-tier (user principal))
  (match (map-get? users user)
    user-data (ok (get tier user-data))
    ERR-NOT-REGISTERED
  )
)

;; Get tier limits
(define-read-only (get-tier-limits (tier uint))
  (map-get? tier-limits tier)
)

;; Get subscription price
(define-read-only (get-tier-price (tier uint))
  (if (is-eq tier TIER-BASIC)
    (ok PRICE-BASIC)
    (if (is-eq tier TIER-PRO)
      (ok PRICE-PRO)
      (if (is-eq tier TIER-ENTERPRISE)
        (ok PRICE-ENTERPRISE)
        ERR-INVALID-TIER
      )
    )
  )
)

;; Get platform stats
(define-read-only (get-stats)
  {
    total-users: (var-get total-users),
    total-revenue: (var-get total-revenue)
  }
)

;; Check if user can create more alerts
(define-read-only (can-create-alert (user principal))
  (match (map-get? users user)
    user-data 
      (match (map-get? tier-limits (get tier user-data))
        limits (< (get alerts-created user-data) (get max-alerts limits))
        false
      )
    false
  )
)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; Register new user with free tier
(define-public (register (username (string-ascii 32)) (referrer (optional principal)))
  (let
    (
      (caller tx-sender)
    )
    ;; Validate inputs - Clarity 4 enhanced string operations
    (asserts! (> (len username) u0) ERR-INVALID-INPUT)
    (asserts! (< (len username) u33) ERR-INVALID-INPUT)
    (asserts! (is-none (map-get? users caller)) ERR-ALREADY-REGISTERED)
    (asserts! (is-none (map-get? usernames username)) ERR-ALREADY-REGISTERED)
    
    ;; Create user profile
    (map-set users caller
      {
        registered-at: stacks-block-height,
        tier: TIER-FREE,
        subscription-expires: u0,
        alerts-created: u0,
        alerts-triggered: u0,
        total-spent: u0,
        referrer: referrer,
        username: username,
        is-active: true
      }
    )
    
    ;; Reserve username
    (map-set usernames username caller)
    
    ;; Increment user count
    (var-set total-users (+ (var-get total-users) u1))
    
    ;; Emit print event for chainhook
    (print {
      event: "user-registered",
      user: caller,
      username: username,
      referrer: referrer,
      block: stacks-block-height
    })
    
    (ok true)
  )
)

;; Subscribe to a paid tier
(define-public (subscribe (tier uint))
  (let
    (
      (caller tx-sender)
      (price (try! (get-tier-price tier)))
      (user-data (unwrap! (map-get? users caller) ERR-NOT-REGISTERED))
      (current-expires (get subscription-expires user-data))
      (new-expires (if (> current-expires stacks-block-height)
                      (+ current-expires SUBSCRIPTION-DURATION)
                      (+ stacks-block-height SUBSCRIPTION-DURATION)))
    )
    ;; Validate tier
    (asserts! (or (is-eq tier TIER-BASIC) (is-eq tier TIER-PRO) (is-eq tier TIER-ENTERPRISE)) ERR-INVALID-TIER)
    
    ;; Transfer payment to fee vault
    (try! (stx-transfer? price caller (var-get fee-vault-principal)))
    
    ;; Update user subscription
    (map-set users caller
      (merge user-data {
        tier: tier,
        subscription-expires: new-expires,
        total-spent: (+ (get total-spent user-data) price)
      })
    )
    
    ;; Update revenue
    (var-set total-revenue (+ (var-get total-revenue) price))
    
    ;; Emit subscription event for chainhook
    (print {
      event: "subscription-created",
      user: caller,
      tier: tier,
      price: price,
      expires-at: new-expires,
      block: stacks-block-height
    })
    
    (ok { tier: tier, expires-at: new-expires })
  )
)

;; Increment user's alert count (called by alert-manager)
(define-public (increment-alerts (user principal))
  (let
    (
      (user-data (unwrap! (map-get? users user) ERR-NOT-REGISTERED))
    )
    ;; Only alert-manager contract can call this
    (asserts! (is-eq contract-caller .alert-manager) ERR-NOT-AUTHORIZED)
    
    (map-set users user
      (merge user-data {
        alerts-created: (+ (get alerts-created user-data) u1)
      })
    )
    (ok true)
  )
)

;; Record triggered alert (called by chainhook server via admin)
(define-public (record-alert-triggered (user principal))
  (let
    (
      (user-data (unwrap! (map-get? users user) ERR-NOT-REGISTERED))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    
    (map-set users user
      (merge user-data {
        alerts-triggered: (+ (get alerts-triggered user-data) u1)
      })
    )
    
    (print {
      event: "alert-triggered",
      user: user,
      total-triggered: (+ (get alerts-triggered user-data) u1),
      block: stacks-block-height
    })
    
    (ok true)
  )
)

;; Update fee vault address (admin only)
(define-public (set-fee-vault (new-vault principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set fee-vault-principal new-vault)
    (ok true)
  )
)

;; Deactivate user account
(define-public (deactivate-account)
  (let
    (
      (caller tx-sender)
      (user-data (unwrap! (map-get? users caller) ERR-NOT-REGISTERED))
    )
    (map-set users caller
      (merge user-data { is-active: false })
    )
    
    (print {
      event: "account-deactivated",
      user: caller,
      block: stacks-block-height
    })
    
    (ok true)
  )
)

```
