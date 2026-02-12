;; EventFlow Subscription Manager Contract
;; Manages user subscriptions, credits, and billing for event processing

;; ====================================
;; Constants
;; ====================================

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u300))
(define-constant err-not-found (err u301))
(define-constant err-unauthorized (err u302))
(define-constant err-insufficient-balance (err u303))
(define-constant err-invalid-tier (err u304))
(define-constant err-invalid-duration (err u305))
(define-constant err-already-subscribed (err u306))
(define-constant err-not-subscribed (err u307))
(define-constant err-invalid-amount (err u308))
(define-constant err-subscription-active (err u309))
(define-constant err-invalid-referral (err u310))

;; Subscription tiers
(define-constant tier-free u0)
(define-constant tier-pro u1)
(define-constant tier-enterprise u2)

;; Pricing (in microSTX)
(define-constant price-pro-monthly u20000000)      ;; 20 STX/month
(define-constant price-enterprise-monthly u100000000) ;; 100 STX/month

;; Credit packages
(define-constant package-small u1000)              ;; 1,000 events
(define-constant package-medium u10000)            ;; 10,000 events
(define-constant package-large u100000)            ;; 100,000 events
(define-constant price-small u5000000)             ;; 5 STX
(define-constant price-medium u40000000)           ;; 40 STX (20% discount)
(define-constant price-large u300000000)           ;; 300 STX (40% discount)

;; Tier limits
(define-constant free-event-limit u100)
(define-constant pro-event-limit u10000)
(define-constant free-workflow-limit u5)

;; Fees
(define-constant upgrade-fee u1000000)             ;; 1 STX
(define-constant cancellation-penalty-percent u30) ;; 30%
(define-constant referral-reward-percent u10)      ;; 10%

;; Time constants
(define-constant blocks-per-month u4320)           ;; ~30 days at 10 min/block

;; ====================================
;; Data Variables
;; ====================================

(define-data-var total-subscriptions uint u0)
(define-data-var total-revenue uint u0)
(define-data-var total-credits-purchased uint u0)

;; ====================================
;; Data Maps
;; ====================================

;; User subscriptions
(define-map subscriptions
  { user: principal }
  {
    tier: uint,
    start-block: uint,
    end-block: uint,
    auto-renew: bool,
    is-active: bool,
    total-paid: uint
  }
)

;; Credit balances
(define-map credit-balances
  { user: principal }
  { balance: uint, lifetime-purchased: uint }
)

;; Usage tracking
(define-map usage-tracking
  { user: principal, period-key: uint }
  {
    events-used: uint,
    credits-consumed: uint,
    last-reset: uint
  }
)

;; Referral system
(define-map referral-codes
  { user: principal }
  {
    code: (string-utf8 20),
    total-referrals: uint,
    total-earnings: uint,
    created-at: uint
  }
)

(define-map referral-usage
  { code: (string-utf8 20) }
  { referrer: principal, usage-count: uint }
)

;; Subscription history
(define-map subscription-history
  { user: principal, subscription-id: uint }
  {
    tier: uint,
    start-block: uint,
    end-block: uint,
    amount-paid: uint,
    status: (string-utf8 20)
  }
)

(define-data-var subscription-history-counter uint u0)

;; ====================================
;; Private Functions
;; ====================================

(define-private (get-current-period-key)
  (/ stacks-block-height blocks-per-month)
)

(define-private (calculate-tier-price (tier uint) (duration uint))
  (if (is-eq tier tier-pro)
    (* price-pro-monthly duration)
    (if (is-eq tier tier-enterprise)
      (* price-enterprise-monthly duration)
      u0
    )
  )
)

(define-private (get-tier-event-limit (tier uint))
  (if (is-eq tier tier-free)
    free-event-limit
    (if (is-eq tier tier-pro)
      pro-event-limit
      u0 ;; Enterprise = unlimited (represented as 0)
    )
  )
)

(define-private (is-subscription-active (user principal))
  (match (map-get? subscriptions { user: user })
    subscription
      (and 
        (get is-active subscription)
        (>= (get end-block subscription) stacks-block-height)
      )
    false
  )
)

(define-private (get-user-tier (user principal))
  (default-to tier-free
    (get tier (map-get? subscriptions { user: user }))
  )
)

(define-private (record-subscription-history
    (user principal)
    (tier uint)
    (start-block uint)
    (end-block uint)
    (amount-paid uint)
    (status (string-utf8 20))
  )
  (let (
    (history-id (+ (var-get subscription-history-counter) u1))
  )
    (map-set subscription-history
      { user: user, subscription-id: history-id }
      {
        tier: tier,
        start-block: start-block,
        end-block: end-block,
        amount-paid: amount-paid,
        status: status
      }
    )
    (var-set subscription-history-counter history-id)
  )
)

(define-private (apply-referral-reward (referrer principal) (amount uint))
  (let (
    (reward (/ (* amount referral-reward-percent) u100))
    (current-balance (default-to 
      { balance: u0, lifetime-purchased: u0 }
      (map-get? credit-balances { user: referrer })
    ))
  )
    (map-set credit-balances
      { user: referrer }
      {
        balance: (+ (get balance current-balance) reward),
        lifetime-purchased: (get lifetime-purchased current-balance)
      }
    )
    
    ;; Update referral earnings
    (match (map-get? referral-codes { user: referrer })
      referral-info
        (map-set referral-codes
          { user: referrer }
          (merge referral-info {
            total-earnings: (+ (get total-earnings referral-info) reward)
          })
        )
      true
    )
  )
)

;; ====================================
;; Public Functions - Subscriptions
;; ====================================

;; Subscribe to a tier
(define-public (subscribe (tier uint) (duration uint) (referral-code (optional (string-utf8 20))))
  (let (
    (caller tx-sender)
    (price (calculate-tier-price tier duration))
    (end-block (+ stacks-block-height (* duration blocks-per-month)))
  )
    ;; Validations
    (asserts! (or (is-eq tier tier-pro) (is-eq tier tier-enterprise)) err-invalid-tier)
    (asserts! (and (>= duration u1) (<= duration u12)) err-invalid-duration)
    (asserts! (not (is-subscription-active caller)) err-already-subscribed)
    
    ;; Process payment
    (try! (stx-transfer? price caller (as-contract tx-sender)))
    (var-set total-revenue (+ (var-get total-revenue) price))
    
    ;; Apply referral if provided
    (match referral-code
      code
        (match (map-get? referral-usage { code: code })
          usage-info
            (begin
              (apply-referral-reward (get referrer usage-info) price)
              (map-set referral-usage
                { code: code }
                (merge usage-info {
                  usage-count: (+ (get usage-count usage-info) u1)
                })
              )
            )
          true
        )
      true
    )
    
    ;; Create subscription
    (map-set subscriptions
      { user: caller }
      {
        tier: tier,
        start-block: stacks-block-height,
        end-block: end-block,
        auto-renew: false,
        is-active: true,
        total-paid: price
      }
    )
    
    ;; Record history
    (record-subscription-history 
      caller tier stacks-block-height end-block price u"active"
    )
    
    (var-set total-subscriptions (+ (var-get total-subscriptions) u1))
    (ok true)
  )
)

;; Renew subscription
(define-public (renew-subscription (auto-renew bool))
  (let (
    (caller tx-sender)
    (subscription (unwrap! (map-get? subscriptions { user: caller }) err-not-subscribed))
    (tier (get tier subscription))
    (price (calculate-tier-price tier u1))
  )
    ;; Validations
    (asserts! (get is-active subscription) err-not-subscribed)
    
    ;; Process payment
    (try! (stx-transfer? price caller (as-contract tx-sender)))
    (var-set total-revenue (+ (var-get total-revenue) price))
    
    ;; Extend subscription
    (map-set subscriptions
      { user: caller }
      (merge subscription {
        end-block: (+ (get end-block subscription) blocks-per-month),
        auto-renew: auto-renew,
        total-paid: (+ (get total-paid subscription) price)
      })
    )
    
    ;; Record history
    (record-subscription-history 
      caller tier stacks-block-height 
      (+ (get end-block subscription) blocks-per-month)
      price u"renewed"
    )
    
    (ok true)
  )
)

;; Upgrade subscription tier
(define-public (upgrade-subscription (new-tier uint))
  (let (
    (caller tx-sender)
    (subscription (unwrap! (map-get? subscriptions { user: caller }) err-not-subscribed))
    (current-tier (get tier subscription))
    (remaining-blocks (- (get end-block subscription) stacks-block-height))
    (old-price (calculate-tier-price current-tier u1))
    (new-price (calculate-tier-price new-tier u1))
    (price-diff (+ (- new-price old-price) upgrade-fee))
  )
    ;; Validations
    (asserts! (> new-tier current-tier) err-invalid-tier)
    (asserts! (get is-active subscription) err-not-subscribed)
    
    ;; Process payment
    (try! (stx-transfer? price-diff caller (as-contract tx-sender)))
    (var-set total-revenue (+ (var-get total-revenue) price-diff))
    
    ;; Upgrade tier
    (map-set subscriptions
      { user: caller }
      (merge subscription {
        tier: new-tier,
        total-paid: (+ (get total-paid subscription) price-diff)
      })
    )
    
    ;; Record history
    (record-subscription-history 
      caller new-tier stacks-block-height (get end-block subscription) 
      price-diff u"upgraded"
    )
    
    (ok true)
  )
)

;; Cancel subscription
(define-public (cancel-subscription)
  (let (
    (caller tx-sender)
    (subscription (unwrap! (map-get? subscriptions { user: caller }) err-not-subscribed))
    (remaining-blocks (- (get end-block subscription) stacks-block-height))
    (tier (get tier subscription))
    (monthly-price (calculate-tier-price tier u1))
    (remaining-value (/ (* monthly-price remaining-blocks) blocks-per-month))
    (penalty (/ (* remaining-value cancellation-penalty-percent) u100))
    (refund (- remaining-value penalty))
  )
    ;; Validations
    (asserts! (get is-active subscription) err-not-subscribed)
    
    ;; Process refund if applicable
    (if (> refund u0)
      (try! (as-contract (stx-transfer? refund tx-sender caller)))
      true
    )
    
    ;; Deactivate subscription
    (map-set subscriptions
      { user: caller }
      (merge subscription {
        is-active: false,
        end-block: stacks-block-height
      })
    )
    
    ;; Record history
    (record-subscription-history 
      caller tier (get start-block subscription) stacks-block-height 
      refund u"cancelled"
    )
    
    (ok refund)
  )
)

;; Pause subscription
(define-public (pause-subscription (pause-until uint))
  (let (
    (caller tx-sender)
    (subscription (unwrap! (map-get? subscriptions { user: caller }) err-not-subscribed))
  )
    ;; Validations
    (asserts! (get is-active subscription) err-not-subscribed)
    (asserts! (> pause-until stacks-block-height) err-invalid-duration)
    
    ;; Extend end date by pause duration
    (map-set subscriptions
      { user: caller }
      (merge subscription {
        end-block: (+ (get end-block subscription) (- pause-until stacks-block-height))
      })
    )
    
    (ok true)
  )
)

;; ====================================
;; Public Functions - Credits
;; ====================================

;; Purchase credit package
(define-public (purchase-credits (package-size uint))
  (let (
    (caller tx-sender)
    (credits (if (is-eq package-size u1)
      package-small
      (if (is-eq package-size u2)
        package-medium
        (if (is-eq package-size u3)
          package-large
          u0
        )
      )
    ))
    (price (if (is-eq package-size u1)
      price-small
      (if (is-eq package-size u2)
        price-medium
        (if (is-eq package-size u3)
          price-large
          u0
        )
      )
    ))
    (current-balance (default-to 
      { balance: u0, lifetime-purchased: u0 }
      (map-get? credit-balances { user: caller })
    ))
  )
    ;; Validations
    (asserts! (> credits u0) err-invalid-amount)
    
    ;; Process payment
    (try! (stx-transfer? price caller (as-contract tx-sender)))
    (var-set total-revenue (+ (var-get total-revenue) price))
    (var-set total-credits-purchased (+ (var-get total-credits-purchased) credits))
    
    ;; Add credits
    (map-set credit-balances
      { user: caller }
      {
        balance: (+ (get balance current-balance) credits),
        lifetime-purchased: (+ (get lifetime-purchased current-balance) credits)
      }
    )
    
    (ok credits)
  )
)

;; Transfer credits to another user
(define-public (transfer-credits (recipient principal) (amount uint))
  (let (
    (caller tx-sender)
    (sender-balance (unwrap! (map-get? credit-balances { user: caller }) err-not-found))
    (recipient-balance (default-to 
      { balance: u0, lifetime-purchased: u0 }
      (map-get? credit-balances { user: recipient })
    ))
  )
    ;; Validations
    (asserts! (>= (get balance sender-balance) amount) err-insufficient-balance)
    (asserts! (> amount u0) err-invalid-amount)
    
    ;; Update sender balance
    (map-set credit-balances
      { user: caller }
      (merge sender-balance {
        balance: (- (get balance sender-balance) amount)
      })
    )
    
    ;; Update recipient balance
    (map-set credit-balances
      { user: recipient }
      {
        balance: (+ (get balance recipient-balance) amount),
        lifetime-purchased: (get lifetime-purchased recipient-balance)
      }
    )
    
    (ok true)
  )
)

;; Consume credits (called by event-processor)
(define-public (consume-credits (user principal) (amount uint))
  (let (
    (balance (unwrap! (map-get? credit-balances { user: user }) err-not-found))
    (period-key (get-current-period-key))
    (usage (default-to 
      { events-used: u0, credits-consumed: u0, last-reset: stacks-block-height }
      (map-get? usage-tracking { user: user, period-key: period-key })
    ))
  )
    ;; Validations
    (asserts! (>= (get balance balance) amount) err-insufficient-balance)
    
    ;; Update balance
    (map-set credit-balances
      { user: user }
      (merge balance {
        balance: (- (get balance balance) amount)
      })
    )
    
    ;; Update usage tracking
    (map-set usage-tracking
      { user: user, period-key: period-key }
      {
        events-used: (+ (get events-used usage) u1),
        credits-consumed: (+ (get credits-consumed usage) amount),
        last-reset: stacks-block-height
      }
    )
    
    (ok true)
  )
)

;; ====================================
;; Public Functions - Referrals
;; ====================================

;; Generate referral code
(define-public (generate-referral-code (code (string-utf8 20)))
  (let ((caller tx-sender))
    ;; Check if code already exists
    (asserts! (is-none (map-get? referral-usage { code: code })) err-already-subscribed)
    
    ;; Create referral code
    (map-set referral-codes
      { user: caller }
      {
        code: code,
        total-referrals: u0,
        total-earnings: u0,
        created-at: stacks-block-height
      }
    )
    
    (map-set referral-usage
      { code: code }
      { referrer: caller, usage-count: u0 }
    )
    
    (ok true)
  )
)

;; ====================================
;; Read-Only Functions
;; ====================================

;; Get subscription status
(define-read-only (get-subscription-status (user principal))
  (ok (map-get? subscriptions { user: user }))
)

;; Get credit balance
(define-read-only (get-credit-balance (user principal))
  (ok (default-to u0
    (get balance (map-get? credit-balances { user: user }))
  ))
)

;; Get usage statistics
(define-read-only (get-usage-stats (user principal))
  (let ((period-key (get-current-period-key)))
    (ok (map-get? usage-tracking { user: user, period-key: period-key }))
  )
)

;; Estimate monthly cost based on usage
(define-read-only (estimate-monthly-cost (user principal))
  (let (
    (period-key (get-current-period-key))
    (usage (map-get? usage-tracking { user: user, period-key: period-key }))
    (credits-used (default-to u0 (get credits-consumed usage)))
  )
    (ok (* credits-used u100000)) ;; 0.1 STX per event
  )
)

;; Get referral earnings
(define-read-only (get-referral-earnings (user principal))
  (ok (default-to u0
    (get total-earnings (map-get? referral-codes { user: user }))
  ))
)

;; Get referral code info
(define-read-only (get-referral-info (code (string-utf8 20)))
  (ok (map-get? referral-usage { code: code }))
)

;; Check if user has active subscription
(define-read-only (has-active-subscription (user principal))
  (ok (is-subscription-active user))
)

;; Get user tier
(define-read-only (get-user-tier-info (user principal))
  (ok (get-user-tier user))
)

;; Get platform revenue statistics
(define-read-only (get-platform-revenue-stats)
  (ok {
    total-subscriptions: (var-get total-subscriptions),
    total-revenue: (var-get total-revenue),
    total-credits-purchased: (var-get total-credits-purchased)
  })
)

;; Get subscription history
(define-read-only (get-subscription-history (user principal) (subscription-id uint))
  (ok (map-get? subscription-history { user: user, subscription-id: subscription-id }))
)

;; Check if user can process events
(define-read-only (can-process-events (user principal))
  (let (
    (tier (get-user-tier user))
    (period-key (get-current-period-key))
    (usage (map-get? usage-tracking { user: user, period-key: period-key }))
    (events-used (default-to u0 (get events-used usage)))
    (limit (get-tier-event-limit tier))
    (has-credits (> (default-to u0 
      (get balance (map-get? credit-balances { user: user }))
    ) u0))
  )
    (ok (or
      (is-eq limit u0) ;; Enterprise = unlimited
      (< events-used limit)
      has-credits
    ))
  )
)
