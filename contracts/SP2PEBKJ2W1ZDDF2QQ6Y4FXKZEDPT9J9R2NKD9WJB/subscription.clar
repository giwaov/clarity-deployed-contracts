;; Stacks Subscription - Recurring Payments
;; On-chain subscription management

(define-constant contract-owner tx-sender)
(define-constant treasury 'SP2PEBKJ2W1ZDDF2QQ6Y4FXKZEDPT9J9R2NKD9WJB)
(define-constant err-not-found (err u100))
(define-constant err-already-subscribed (err u101))
(define-constant err-not-subscribed (err u102))
(define-constant err-expired (err u103))

;; Subscription tiers
(define-constant TIER-BASIC u1)
(define-constant TIER-PRO u2)
(define-constant TIER-ENTERPRISE u3)

;; Prices per month (in blocks ~4320)
(define-constant PRICE-BASIC u5000000)      ;; 5 STX
(define-constant PRICE-PRO u15000000)       ;; 15 STX
(define-constant PRICE-ENTERPRISE u50000000) ;; 50 STX
(define-constant MONTH-BLOCKS u4320)

(define-data-var total-subscribers uint u0)
(define-data-var total-revenue uint u0)

(define-map subscriptions principal
  {
    tier: uint,
    start-block: uint,
    end-block: uint,
    auto-renew: bool,
    total-paid: uint
  }
)

(define-map tier-stats uint
  {
    subscribers: uint,
    revenue: uint
  }
)

(define-read-only (get-subscription (user principal))
  (map-get? subscriptions user)
)

(define-read-only (is-active (user principal))
  (match (map-get? subscriptions user)
    sub (<= stacks-block-height (get end-block sub))
    false
  )
)

(define-read-only (get-tier (user principal))
  (match (map-get? subscriptions user)
    sub (if (is-active user) (get tier sub) u0)
    u0
  )
)

(define-read-only (get-tier-price (tier uint))
  (if (is-eq tier TIER-BASIC) PRICE-BASIC
    (if (is-eq tier TIER-PRO) PRICE-PRO
      (if (is-eq tier TIER-ENTERPRISE) PRICE-ENTERPRISE
        u0
      )
    )
  )
)

(define-read-only (get-stats)
  {
    total-subscribers: (var-get total-subscribers),
    total-revenue: (var-get total-revenue)
  }
)

(define-public (subscribe (tier uint) (months uint))
  (let (
    (price (* (get-tier-price tier) months))
    (duration (* MONTH-BLOCKS months))
    (existing (map-get? subscriptions tx-sender))
  )
    (asserts! (> price u0) err-not-found)
    
    (match existing
      sub
      ;; Extend existing subscription
      (map-set subscriptions tx-sender
        (merge sub {
          tier: tier,
          end-block: (+ (get end-block sub) duration),
          total-paid: (+ (get total-paid sub) price)
        })
      )
      ;; New subscription
      (begin
        (map-set subscriptions tx-sender {
          tier: tier,
          start-block: stacks-block-height,
          end-block: (+ stacks-block-height duration),
          auto-renew: false,
          total-paid: price
        })
        (var-set total-subscribers (+ (var-get total-subscribers) u1))
      )
    )
    
    (var-set total-revenue (+ (var-get total-revenue) price))
    
    (ok { tier: tier, months: months, end-block: (+ stacks-block-height duration) })
  )
)

(define-public (set-auto-renew (enabled bool))
  (match (map-get? subscriptions tx-sender)
    sub
    (begin
      (map-set subscriptions tx-sender (merge sub { auto-renew: enabled }))
      (ok true)
    )
    err-not-subscribed
  )
)

(define-public (cancel-subscription)
  (match (map-get? subscriptions tx-sender)
    sub
    (begin
      (map-set subscriptions tx-sender (merge sub { auto-renew: false }))
      (ok true)
    )
    err-not-subscribed
  )
)

