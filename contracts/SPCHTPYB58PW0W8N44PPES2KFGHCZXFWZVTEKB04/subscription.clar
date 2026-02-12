;; Subscription Service Contract
;; Recurring payment subscriptions

(define-constant contract-owner tx-sender)
(define-constant err-not-subscribed (err u100))
(define-constant err-subscription-expired (err u101))
(define-constant err-insufficient-payment (err u102))

(define-constant subscription-duration u4320) ;; ~30 days in blocks

(define-map subscriptions
    principal
    {
        start-block: uint,
        end-block: uint,
        tier: (string-ascii 20),
        auto-renew: bool
    }
)

(define-map tier-prices (string-ascii 20) uint)

;; Initialize tier prices
(map-set tier-prices "basic" u5000000)    ;; 5 STX
(map-set tier-prices "premium" u10000000) ;; 10 STX
(map-set tier-prices "pro" u20000000)     ;; 20 STX

;; Subscribe to a tier
(define-public (subscribe (tier (string-ascii 20)))
    (let
        (
            (price (unwrap! (map-get? tier-prices tier) err-insufficient-payment))
            (end-block (+ block-height subscription-duration))
        )
        (try! (stx-transfer? price tx-sender contract-owner))
        
        (map-set subscriptions tx-sender {
            start-block: block-height,
            end-block: end-block,
            tier: tier,
            auto-renew: false
        })
        
        (ok end-block)
    )
)

;; Renew subscription
(define-public (renew)
    (let
        (
            (sub (unwrap! (map-get? subscriptions tx-sender) err-not-subscribed))
            (price (unwrap! (map-get? tier-prices (get tier sub)) err-insufficient-payment))
            (new-end-block (+ (get end-block sub) subscription-duration))
        )
        (try! (stx-transfer? price tx-sender contract-owner))
        
        (map-set subscriptions tx-sender (merge sub {
            end-block: new-end-block
        }))
        
        (ok new-end-block)
    )
)

;; Cancel subscription
(define-public (cancel-subscription)
    (begin
        (asserts! (is-some (map-get? subscriptions tx-sender)) err-not-subscribed)
        (map-delete subscriptions tx-sender)
        (ok true)
    )
)

;; Toggle auto-renew
(define-public (toggle-auto-renew)
    (let
        (
            (sub (unwrap! (map-get? subscriptions tx-sender) err-not-subscribed))
        )
        (map-set subscriptions tx-sender (merge sub {
            auto-renew: (not (get auto-renew sub))
        }))
        (ok (not (get auto-renew sub)))
    )
)

;; Update tier price (owner only)
(define-public (update-tier-price (tier (string-ascii 20)) (new-price uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-subscribed)
        (map-set tier-prices tier new-price)
        (ok true)
    )
)

;; Check if subscription is active
(define-read-only (is-subscribed (user principal))
    (match (map-get? subscriptions user)
        sub (> (get end-block sub) block-height)
        false
    )
)

;; Get subscription info
(define-read-only (get-subscription (user principal))
    (map-get? subscriptions user)
)

;; Get tier price
(define-read-only (get-tier-price (tier (string-ascii 20)))
    (map-get? tier-prices tier)
)

;; Check time remaining
(define-read-only (blocks-remaining (user principal))
    (match (map-get? subscriptions user)
        sub (if (> (get end-block sub) block-height)
                (- (get end-block sub) block-height)
                u0)
        u0
    )
)
