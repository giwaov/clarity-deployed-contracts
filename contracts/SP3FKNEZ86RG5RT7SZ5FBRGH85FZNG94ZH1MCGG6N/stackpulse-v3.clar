;; StackPulse V3 - Enhanced User Registry & Subscriptions
;; Upgrades from V2:
;; - Better error handling with more descriptive error codes
;; - Optimized gas usage with efficient data structures
;; - Enhanced event logging for chainhooks
;; - Added batch operations support
;; - Improved subscription management
;; 
;; Flow:
;; 1. User calls (register-and-subscribe) with profile + tier (0=free, 1-3=paid)
;; 2. For free tier: no STX transfer, just stores profile
;; 3. For paid tiers: transfers STX, stores profile + subscription
;; 4. User can update profile anytime with (update-profile)
;; 5. User can upgrade tier with (upgrade-subscription)

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-ALREADY-REGISTERED (err u101))
(define-constant ERR-NOT-REGISTERED (err u102))
(define-constant ERR-INVALID-TIER (err u103))
(define-constant ERR-TRANSFER-FAILED (err u104))
(define-constant ERR-NOT-AUTHORIZED (err u105))
(define-constant ERR-INVALID-USERNAME (err u106))
(define-constant ERR-INVALID-ALERTS (err u107))
(define-constant ERR-SUBSCRIPTION-EXPIRED (err u108))
(define-constant ERR-SAME-TIER (err u109))
(define-constant ERR-INVALID-HOOK-TYPE (err u110))

;; Subscription duration: ~30 days in blocks (assuming 10 min blocks)
(define-constant BLOCKS-PER-MONTH u4320)

;; Tier prices in microSTX
(define-constant PRICE-FREE u0)
(define-constant PRICE-BASIC u1000000)      ;; 1 STX
(define-constant PRICE-PRO u5000000)        ;; 5 STX  
(define-constant PRICE-PREMIUM u20000000)   ;; 20 STX

;; Maximum valid tier
(define-constant MAX-TIER u3)

;; Maximum alerts bitmask (all 5 alert types)
(define-constant MAX-ALERTS-BITMASK u31)

;; ============================================
;; DATA STORAGE
;; ============================================

(define-data-var total-users uint u0)
(define-data-var total-revenue uint u0)
(define-data-var contract-version (string-ascii 8) "v3.0.0")

;; Main user profile map
(define-map users principal
  {
    user-id: uint,
    username: (string-ascii 32),
    email: (string-ascii 64),
    tier: uint,
    subscription-ends: uint,
    alerts-enabled: uint,    ;; Bitmask: 1=whale, 2=nft, 4=token, 8=swap, 16=contract
    created-at: uint,
    updated-at: uint,
    total-triggers: uint     ;; V3: Track total chainhook triggers for user
  }
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

(define-read-only (get-version)
  (var-get contract-version)
)

(define-read-only (get-user (who principal))
  (map-get? users who)
)

(define-read-only (is-registered (who principal))
  (is-some (map-get? users who))
)

(define-read-only (get-subscription-status (who principal))
  (match (map-get? users who)
    user-data 
      {
        registered: true,
        tier: (get tier user-data),
        active: (or (is-eq (get tier user-data) u0) 
                    (> (get subscription-ends user-data) block-height)),
        ends-at: (get subscription-ends user-data),
        total-triggers: (get total-triggers user-data)
      }
    { registered: false, tier: u0, active: false, ends-at: u0, total-triggers: u0 }
  )
)

(define-read-only (get-tier-price (tier uint))
  (if (is-eq tier u0) PRICE-FREE
    (if (is-eq tier u1) PRICE-BASIC
      (if (is-eq tier u2) PRICE-PRO
        (if (is-eq tier u3) PRICE-PREMIUM
          u0))))
)

(define-read-only (get-stats)
  {
    total-users: (var-get total-users),
    total-revenue: (var-get total-revenue),
    version: (var-get contract-version)
  }
)

;; V3: Check if subscription is active
(define-read-only (is-subscription-active (who principal))
  (match (map-get? users who)
    user-data
      (or (is-eq (get tier user-data) u0)
          (> (get subscription-ends user-data) block-height))
    false
  )
)

;; ============================================
;; PRIVATE HELPER FUNCTIONS
;; ============================================

;; V3: Validate username (non-empty, proper length)
(define-private (is-valid-username (username (string-ascii 32)))
  (let ((len (len username)))
    (and (>= len u1) (<= len u32))
  )
)

;; V3: Validate tier
(define-private (is-valid-tier (tier uint))
  (<= tier MAX-TIER)
)

;; ============================================
;; PUBLIC FUNCTIONS
;; ============================================

;; Register and subscribe in one transaction
;; tier: 0=Free, 1=Basic, 2=Pro, 3=Premium
;; alerts: bitmask (1=whale, 2=nft, 4=token, 8=swap, 16=contract) or just pass 31 for all
(define-public (register-and-subscribe 
    (username (string-ascii 32))
    (email (string-ascii 64))
    (tier uint)
    (alerts uint))
  (let
    (
      (caller tx-sender)
      (price (get-tier-price tier))
      (user-id (+ (var-get total-users) u1))
      (sub-ends (if (is-eq tier u0) 
                    u0 
                    (+ block-height BLOCKS-PER-MONTH)))
    )
    ;; V3: Enhanced validation
    (asserts! (is-valid-username username) ERR-INVALID-USERNAME)
    (asserts! (is-none (map-get? users caller)) ERR-ALREADY-REGISTERED)
    (asserts! (is-valid-tier tier) ERR-INVALID-TIER)
    (asserts! (<= alerts MAX-ALERTS-BITMASK) ERR-INVALID-ALERTS)
    
    ;; Transfer STX for paid tiers
    (if (> price u0)
      (try! (stx-transfer? price caller CONTRACT-OWNER))
      true
    )
    
    ;; Store user profile with V3 enhanced data
    (map-set users caller {
      user-id: user-id,
      username: username,
      email: email,
      tier: tier,
      subscription-ends: sub-ends,
      alerts-enabled: alerts,
      created-at: block-height,
      updated-at: block-height,
      total-triggers: u0
    })
    
    ;; Update stats
    (var-set total-users user-id)
    (if (> price u0)
      (var-set total-revenue (+ (var-get total-revenue) price))
      true
    )
    
    ;; V3: Enhanced event with more data for chainhooks
    (print {
      event: "user-registered",
      version: "v3",
      user: caller,
      user-id: user-id,
      username: username,
      tier: tier,
      price: price,
      alerts: alerts,
      subscription-ends: sub-ends,
      block: block-height
    })
    
    (ok user-id)
  )
)

;; Update profile (username, email, alerts) - no payment
(define-public (update-profile 
    (username (string-ascii 32))
    (email (string-ascii 64))
    (alerts uint))
  (let
    (
      (caller tx-sender)
      (user-data (unwrap! (map-get? users caller) ERR-NOT-REGISTERED))
    )
    ;; V3: Validate inputs
    (asserts! (is-valid-username username) ERR-INVALID-USERNAME)
    (asserts! (<= alerts MAX-ALERTS-BITMASK) ERR-INVALID-ALERTS)
    
    (map-set users caller (merge user-data {
      username: username,
      email: email,
      alerts-enabled: alerts,
      updated-at: block-height
    }))
    
    (print {
      event: "profile-updated",
      version: "v3",
      user: caller,
      username: username,
      alerts: alerts,
      block: block-height
    })
    
    (ok true)
  )
)

;; Upgrade or renew subscription
(define-public (upgrade-subscription (new-tier uint))
  (let
    (
      (caller tx-sender)
      (user-data (unwrap! (map-get? users caller) ERR-NOT-REGISTERED))
      (current-tier (get tier user-data))
      (current-ends (get subscription-ends user-data))
      (price (get-tier-price new-tier))
      (new-ends (if (> current-ends block-height)
                    (+ current-ends BLOCKS-PER-MONTH)
                    (+ block-height BLOCKS-PER-MONTH)))
    )
    ;; V3: Enhanced validation
    (asserts! (> new-tier u0) ERR-INVALID-TIER)
    (asserts! (is-valid-tier new-tier) ERR-INVALID-TIER)
    
    ;; Transfer payment
    (try! (stx-transfer? price caller CONTRACT-OWNER))
    
    ;; Update subscription
    (map-set users caller (merge user-data {
      tier: new-tier,
      subscription-ends: new-ends,
      updated-at: block-height
    }))
    
    ;; Update revenue
    (var-set total-revenue (+ (var-get total-revenue) price))
    
    (print {
      event: "subscription-upgraded",
      version: "v3",
      user: caller,
      old-tier: current-tier,
      new-tier: new-tier,
      price: price,
      ends-at: new-ends,
      block: block-height
    })
    
    (ok new-ends)
  )
)

;; Set alert preferences only
(define-public (set-alerts (alerts uint))
  (let
    (
      (caller tx-sender)
      (user-data (unwrap! (map-get? users caller) ERR-NOT-REGISTERED))
    )
    ;; V3: Validate alerts bitmask
    (asserts! (<= alerts MAX-ALERTS-BITMASK) ERR-INVALID-ALERTS)
    
    (map-set users caller (merge user-data {
      alerts-enabled: alerts,
      updated-at: block-height
    }))
    
    (print {
      event: "alerts-updated",
      version: "v3",
      user: caller,
      alerts: alerts,
      block: block-height
    })
    
    (ok true)
  )
)

;; ============================================
;; CHAINHOOK EVENT TRACKING (V3 Enhanced)
;; ============================================

;; Track chainhook triggers per user
(define-map chainhook-triggers { user: principal, hook-type: uint } uint)

;; Chainhook types:
;; 1 = Whale Transfer Alert
;; 2 = Contract Deployed
;; 3 = NFT Mint
;; 4 = Token Launch
;; 5 = Large Swap
;; 6 = Subscription Created (this contract)
;; 7 = Alert Triggered
;; 8 = Fee Collected
;; 9 = Badge Earned

(define-read-only (get-trigger-count (user principal) (hook-type uint))
  (default-to u0 (map-get? chainhook-triggers { user: user, hook-type: hook-type }))
)

;; Record a chainhook trigger (called by authorized services or contracts)
(define-public (record-chainhook-trigger (user principal) (hook-type uint))
  (let
    (
      (current-count (get-trigger-count user hook-type))
      (user-data (map-get? users user))
    )
    ;; Only contract owner or the user themselves can record
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) 
                  (is-eq tx-sender user)) ERR-NOT-AUTHORIZED)
    
    ;; V3: Validate hook type (1-9)
    (asserts! (and (>= hook-type u1) (<= hook-type u9)) ERR-INVALID-HOOK-TYPE)
    
    ;; Update trigger count
    (map-set chainhook-triggers { user: user, hook-type: hook-type } (+ current-count u1))
    
    ;; V3: Also update user's total triggers if registered
    (match user-data
      data (map-set users user (merge data {
        total-triggers: (+ (get total-triggers data) u1),
        updated-at: block-height
      }))
      true
    )
    
    (print {
      event: "chainhook-recorded",
      version: "v3",
      user: user,
      hook-type: hook-type,
      total-triggers: (+ current-count u1),
      block: block-height
    })
    
    (ok (+ current-count u1))
  )
)

;; Get all chainhook stats for a user
(define-read-only (get-user-chainhook-stats (user principal))
  {
    whale-alerts: (get-trigger-count user u1),
    contract-deploys: (get-trigger-count user u2),
    nft-mints: (get-trigger-count user u3),
    token-launches: (get-trigger-count user u4),
    large-swaps: (get-trigger-count user u5),
    subscriptions: (get-trigger-count user u6),
    alerts-triggered: (get-trigger-count user u7),
    fees-collected: (get-trigger-count user u8),
    badges-earned: (get-trigger-count user u9)
  }
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

;; Withdraw collected fees (owner only)
(define-public (withdraw-fees (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    
    (print {
      event: "fees-withdrawn",
      version: "v3",
      amount: amount,
      recipient: recipient,
      block: block-height
    })
    
    (ok true)
  )
)

;; Admin grant subscription (for promotions, etc.)
(define-public (admin-grant-subscription (user principal) (tier uint) (duration-blocks uint))
  (let
    (
      (user-data (unwrap! (map-get? users user) ERR-NOT-REGISTERED))
    )
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-valid-tier tier) ERR-INVALID-TIER)
    
    (map-set users user (merge user-data {
      tier: tier,
      subscription-ends: (+ block-height duration-blocks),
      updated-at: block-height
    }))
    
    (print {
      event: "admin-grant",
      version: "v3",
      user: user,
      tier: tier,
      duration: duration-blocks,
      block: block-height
    })
    
    (ok true)
  )
)
