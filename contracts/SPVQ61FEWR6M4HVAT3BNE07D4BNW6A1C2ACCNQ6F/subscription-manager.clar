;; StackStream Subscription Manager Contract
;; Handles recurring subscriptions with automated billing cycles

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))
(define-constant err-not-found (err u201))
(define-constant err-already-exists (err u202))
(define-constant err-insufficient-funds (err u203))
(define-constant err-unauthorized (err u204))
(define-constant err-invalid-input (err u205))
(define-constant err-subscription-expired (err u206))
(define-constant err-subscription-active (err u207))

;; Revenue split constants
(define-constant creator-share u8500) ;; 85% = 8500/10000
(define-constant platform-share u1000) ;; 10% = 1000/10000
(define-constant referrer-share u500) ;; 5% = 500/10000

;; Fee constants
(define-constant tier-upgrade-fee u2000000) ;; 2 STX in microSTX
(define-constant early-cancel-penalty u2000) ;; 20% = 2000/10000
(define-constant grace-period-blocks u144) ;; ~1 day (assuming 10 min blocks)

;; Subscription tier limits (in microSTX per month)
(define-constant tier-basic-min u5000000) ;; 5 STX
(define-constant tier-basic-max u25000000) ;; 25 STX
(define-constant tier-premium-min u25000001) ;; 25.000001 STX
(define-constant tier-premium-max u50000000) ;; 50 STX
(define-constant tier-vip-min u50000001) ;; 50.000001 STX
(define-constant tier-vip-max u100000000) ;; 100 STX

;; Blocks per month (approximate: 30 days * 144 blocks/day)
(define-constant blocks-per-month u4320)

;; Data Variables
(define-data-var total-subscriptions uint u0)
(define-data-var total-active-subscriptions uint u0)
(define-data-var platform-treasury principal contract-owner)

;; Data Maps

;; Subscription tiers definition
(define-map subscription-tiers
    {creator: principal, tier-name: (string-ascii 20)}
    {
        monthly-price: uint,
        tier-level: uint, ;; 1=Basic, 2=Premium, 3=VIP
        benefits: (string-utf8 500),
        max-subscribers: uint,
        current-subscribers: uint,
        is-active: bool,
        created-at: uint
    }
)

;; Active subscriptions
(define-map subscriptions
    {subscriber: principal, creator: principal}
    {
        tier-name: (string-ascii 20),
        monthly-price: uint,
        start-block: uint,
        last-payment-block: uint,
        next-payment-block: uint,
        auto-renew: bool,
        referred-by: (optional principal),
        total-paid: uint,
        is-active: bool
    }
)

;; Subscription history for renewals
(define-map subscription-payments
    {subscriber: principal, creator: principal, payment-id: uint}
    {
        amount: uint,
        payment-block: uint,
        tier-name: (string-ascii 20)
    }
)

(define-map subscriber-payment-count {subscriber: principal, creator: principal} uint)

;; Creator subscription stats
(define-map creator-subscription-stats
    principal
    {
        total-subscribers: uint,
        active-subscribers: uint,
        total-revenue: uint,
        monthly-revenue: uint
    }
)

;; Referral tracking
(define-map referral-earnings principal uint)

;; Private Functions

(define-private (calculate-share (amount uint) (share-percent uint))
    (/ (* amount share-percent) u10000)
)

(define-private (get-tier-level (price uint))
    (if (and (>= price tier-basic-min) (<= price tier-basic-max))
        u1
        (if (and (>= price tier-premium-min) (<= price tier-premium-max))
            u2
            (if (and (>= price tier-vip-min) (<= price tier-vip-max))
                u3
                u0
            )
        )
    )
)

(define-private (is-valid-tier-price (price uint))
    (> (get-tier-level price) u0)
)

(define-private (distribute-subscription-payment (amount uint) 
                                                 (creator principal) 
                                                 (referrer (optional principal)))
    (let (
        (creator-amount (calculate-share amount creator-share))
        (platform-amount (calculate-share amount platform-share))
        (referrer-amount (calculate-share amount referrer-share))
    )
        ;; Pay creator
        (try! (stx-transfer? creator-amount tx-sender creator))
        
        ;; Pay platform
        (try! (stx-transfer? platform-amount tx-sender (var-get platform-treasury)))
        
        ;; Pay referrer if exists
        (match referrer
            ref-principal 
                (begin
                    (try! (stx-transfer? referrer-amount tx-sender ref-principal))
                    ;; Track referral earnings
                    (map-set referral-earnings ref-principal 
                        (+ (default-to u0 (map-get? referral-earnings ref-principal)) referrer-amount)
                    )
                )
            ;; If no referrer, send referrer share to platform
            (try! (stx-transfer? referrer-amount tx-sender (var-get platform-treasury)))
        )
        
        (ok true)
    )
)

(define-private (update-creator-stats (creator principal) (amount uint) (is-new bool))
    (let (
        (stats (default-to 
            {total-subscribers: u0, active-subscribers: u0, total-revenue: u0, monthly-revenue: u0}
            (map-get? creator-subscription-stats creator)
        ))
    )
        (map-set creator-subscription-stats creator {
            total-subscribers: (if is-new 
                (+ (get total-subscribers stats) u1) 
                (get total-subscribers stats)
            ),
            active-subscribers: (+ (get active-subscribers stats) u1),
            total-revenue: (+ (get total-revenue stats) amount),
            monthly-revenue: (+ (get monthly-revenue stats) amount)
        })
        true
    )
)

;; Public Functions

;; Create a subscription tier
(define-public (create-subscription-tier (tier-name (string-ascii 20))
                                        (monthly-price uint)
                                        (benefits (string-utf8 500))
                                        (max-subscribers uint))
    (let (
        (creator tx-sender)
        (tier-key {creator: creator, tier-name: tier-name})
    )
        ;; Validate inputs
        (asserts! (is-valid-tier-price monthly-price) err-invalid-input)
        (asserts! (is-none (map-get? subscription-tiers tier-key)) err-already-exists)
        (asserts! (> max-subscribers u0) err-invalid-input)
        
        ;; Create tier
        (map-set subscription-tiers tier-key {
            monthly-price: monthly-price,
            tier-level: (get-tier-level monthly-price),
            benefits: benefits,
            max-subscribers: max-subscribers,
            current-subscribers: u0,
            is-active: true,
            created-at: stacks-block-height
        })
        
        (ok true)
    )
)

;; Subscribe to a creator
(define-public (subscribe (creator principal) 
                         (tier-name (string-ascii 20))
                         (referred-by (optional principal)))
    (let (
        (subscriber tx-sender)
        (tier-key {creator: creator, tier-name: tier-name})
        (tier-data (unwrap! (map-get? subscription-tiers tier-key) err-not-found))
        (sub-key {subscriber: subscriber, creator: creator})
        (price (get monthly-price tier-data))
    )
        ;; Validate subscription
        (asserts! (get is-active tier-data) err-invalid-input)
        (asserts! (< (get current-subscribers tier-data) (get max-subscribers tier-data)) err-invalid-input)
        (asserts! (is-none (map-get? subscriptions sub-key)) err-already-exists)
        
        ;; Process payment and distribute
        (try! (distribute-subscription-payment price creator referred-by))
        
        ;; Create subscription
        (map-set subscriptions sub-key {
            tier-name: tier-name,
            monthly-price: price,
            start-block: stacks-block-height,
            last-payment-block: stacks-block-height,
            next-payment-block: (+ stacks-block-height blocks-per-month),
            auto-renew: true,
            referred-by: referred-by,
            total-paid: price,
            is-active: true
        })
        
        ;; Update tier subscriber count
        (map-set subscription-tiers tier-key
            (merge tier-data {
                current-subscribers: (+ (get current-subscribers tier-data) u1)
            })
        )
        
        ;; Record payment
        (let ((payment-count (+ (default-to u0 (map-get? subscriber-payment-count sub-key)) u1)))
            (map-set subscription-payments 
                {subscriber: subscriber, creator: creator, payment-id: payment-count}
                {
                    amount: price,
                    payment-block: stacks-block-height,
                    tier-name: tier-name
                }
            )
            (map-set subscriber-payment-count sub-key payment-count)
        )
        
        ;; Update stats
        (update-creator-stats creator price true)
        (var-set total-subscriptions (+ (var-get total-subscriptions) u1))
        (var-set total-active-subscriptions (+ (var-get total-active-subscriptions) u1))
        
        (ok true)
    )
)

;; Renew subscription (manual or can be called by automation)
(define-public (renew-subscription (creator principal))
    (let (
        (subscriber tx-sender)
        (sub-key {subscriber: subscriber, creator: creator})
        (sub-data (unwrap! (map-get? subscriptions sub-key) err-not-found))
        (price (get monthly-price sub-data))
    )
        ;; Check if subscription is active and due for renewal
        (asserts! (get is-active sub-data) err-subscription-expired)
        (asserts! (>= stacks-block-height (get next-payment-block sub-data)) err-subscription-active)
        
        ;; Allow grace period
        (asserts! (<= stacks-block-height (+ (get next-payment-block sub-data) grace-period-blocks)) 
            err-subscription-expired)
        
        ;; Process payment
        (try! (distribute-subscription-payment price creator (get referred-by sub-data)))
        
        ;; Update subscription
        (map-set subscriptions sub-key
            (merge sub-data {
                last-payment-block: stacks-block-height,
                next-payment-block: (+ stacks-block-height blocks-per-month),
                total-paid: (+ (get total-paid sub-data) price)
            })
        )
        
        ;; Record payment
        (let ((payment-count (+ (default-to u0 (map-get? subscriber-payment-count sub-key)) u1)))
            (map-set subscription-payments 
                {subscriber: subscriber, creator: creator, payment-id: payment-count}
                {
                    amount: price,
                    payment-block: stacks-block-height,
                    tier-name: (get tier-name sub-data)
                }
            )
            (map-set subscriber-payment-count sub-key payment-count)
        )
        
        ;; Update stats
        (update-creator-stats creator price false)
        
        (ok true)
    )
)

;; Cancel subscription
(define-public (cancel-subscription (creator principal))
    (let (
        (subscriber tx-sender)
        (sub-key {subscriber: subscriber, creator: creator})
        (sub-data (unwrap! (map-get? subscriptions sub-key) err-not-found))
        (tier-key {creator: creator, tier-name: (get tier-name sub-data)})
        (tier-data (unwrap! (map-get? subscription-tiers tier-key) err-not-found))
        (is-early (< stacks-block-height (get next-payment-block sub-data)))
    )
        ;; Check if active
        (asserts! (get is-active sub-data) err-subscription-expired)
        
        ;; Calculate penalty for early cancellation
        (if is-early
            (let (
                (remaining-value (get monthly-price sub-data))
                (penalty (calculate-share remaining-value early-cancel-penalty))
            )
                ;; Charge penalty
                (try! (stx-transfer? penalty subscriber (var-get platform-treasury)))
                true
            )
            true
        )
        
        ;; Deactivate subscription
        (map-set subscriptions sub-key
            (merge sub-data {
                is-active: false,
                auto-renew: false
            })
        )
        
        ;; Update tier subscriber count
        (map-set subscription-tiers tier-key
            (merge tier-data {
                current-subscribers: (- (get current-subscribers tier-data) u1)
            })
        )
        
        ;; Update active subscriptions count
        (var-set total-active-subscriptions (- (var-get total-active-subscriptions) u1))
        
        (ok true)
    )
)

;; Upgrade subscription tier
(define-public (upgrade-subscription (creator principal) (new-tier-name (string-ascii 20)))
    (let (
        (subscriber tx-sender)
        (sub-key {subscriber: subscriber, creator: creator})
        (sub-data (unwrap! (map-get? subscriptions sub-key) err-not-found))
        (old-tier-key {creator: creator, tier-name: (get tier-name sub-data)})
        (new-tier-key {creator: creator, tier-name: new-tier-name})
        (old-tier-data (unwrap! (map-get? subscription-tiers old-tier-key) err-not-found))
        (new-tier-data (unwrap! (map-get? subscription-tiers new-tier-key) err-not-found))
    )
        ;; Validate upgrade
        (asserts! (get is-active sub-data) err-subscription-expired)
        (asserts! (> (get tier-level new-tier-data) (get tier-level old-tier-data)) err-invalid-input)
        (asserts! (< (get current-subscribers new-tier-data) (get max-subscribers new-tier-data)) 
            err-invalid-input)
        
        ;; Charge upgrade fee
        (try! (stx-transfer? tier-upgrade-fee subscriber (var-get platform-treasury)))
        
        ;; Calculate price difference for immediate payment
        (let ((price-diff (- (get monthly-price new-tier-data) (get monthly-price sub-data))))
            (try! (distribute-subscription-payment price-diff creator (get referred-by sub-data)))
        )
        
        ;; Update subscription
        (map-set subscriptions sub-key
            (merge sub-data {
                tier-name: new-tier-name,
                monthly-price: (get monthly-price new-tier-data)
            })
        )
        
        ;; Update tier subscriber counts
        (map-set subscription-tiers old-tier-key
            (merge old-tier-data {
                current-subscribers: (- (get current-subscribers old-tier-data) u1)
            })
        )
        (map-set subscription-tiers new-tier-key
            (merge new-tier-data {
                current-subscribers: (+ (get current-subscribers new-tier-data) u1)
            })
        )
        
        (ok true)
    )
)

;; Toggle auto-renewal
(define-public (toggle-auto-renew (creator principal))
    (let (
        (subscriber tx-sender)
        (sub-key {subscriber: subscriber, creator: creator})
        (sub-data (unwrap! (map-get? subscriptions sub-key) err-not-found))
    )
        (asserts! (get is-active sub-data) err-subscription-expired)
        
        (map-set subscriptions sub-key
            (merge sub-data {
                auto-renew: (not (get auto-renew sub-data))
            })
        )
        
        (ok true)
    )
)

;; Check if subscription grants access (called by content contracts)
(define-public (check-subscription-access (subscriber principal) (creator principal))
    (let (
        (sub-key {subscriber: subscriber, creator: creator})
        (sub-data (unwrap! (map-get? subscriptions sub-key) err-not-found))
    )
        ;; Check if subscription is active and not expired (including grace period)
        (asserts! (get is-active sub-data) err-subscription-expired)
        (asserts! (<= stacks-block-height (+ (get next-payment-block sub-data) grace-period-blocks))
            err-subscription-expired)
        
        (ok true)
    )
)

;; Read-only Functions

(define-read-only (get-subscription-tier (creator principal) (tier-name (string-ascii 20)))
    (ok (map-get? subscription-tiers {creator: creator, tier-name: tier-name}))
)

(define-read-only (get-subscription (subscriber principal) (creator principal))
    (ok (map-get? subscriptions {subscriber: subscriber, creator: creator}))
)

(define-read-only (get-creator-stats (creator principal))
    (ok (map-get? creator-subscription-stats creator))
)

(define-read-only (get-referral-earnings (referrer principal))
    (ok (default-to u0 (map-get? referral-earnings referrer)))
)

(define-read-only (get-total-subscriptions)
    (ok (var-get total-subscriptions))
)

(define-read-only (get-total-active-subscriptions)
    (ok (var-get total-active-subscriptions))
)

(define-read-only (is-subscription-active (subscriber principal) (creator principal))
    (match (map-get? subscriptions {subscriber: subscriber, creator: creator})
        sub-data (ok (and 
            (get is-active sub-data)
            (<= stacks-block-height (+ (get next-payment-block sub-data) grace-period-blocks))
        ))
        (ok false)
    )
)

;; Admin Functions

(define-public (set-platform-treasury (new-treasury principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set platform-treasury new-treasury)
        (ok true)
    )
)

(define-public (deactivate-tier (creator principal) (tier-name (string-ascii 20)))
    (let (
        (tier-key {creator: creator, tier-name: tier-name})
        (tier-data (unwrap! (map-get? subscription-tiers tier-key) err-not-found))
    )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        
        (map-set subscription-tiers tier-key
            (merge tier-data {is-active: false})
        )
        
        (ok true)
    )
)
