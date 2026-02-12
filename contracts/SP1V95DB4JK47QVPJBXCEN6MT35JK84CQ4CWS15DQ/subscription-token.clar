(define-fungible-token subscription-token)

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-SUBSCRIPTION-EXPIRED (err u410))
(define-constant ERR-NOT-FOUND (err u404))

(define-data-var token-name (string-ascii 32) "SubscriptionToken")
(define-data-var token-symbol (string-ascii 10) "SUB")
(define-data-var token-decimals uint u0)

(define-map subscriptions
    principal
    {
        start-time: uint,
        end-time: uint,
        tier: uint,
        auto-renew: bool
    }
)

(define-map subscription-tiers
    uint
    {
        price: uint,
        duration: uint,
        benefits: (string-utf8 256)
    }
)

(define-read-only (get-name)
    (ok (var-get token-name))
)

(define-read-only (get-symbol)
    (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
    (ok (var-get token-decimals))
)

(define-read-only (get-balance (account principal))
    (ok (ft-get-balance subscription-token account))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply subscription-token))
)

(define-read-only (get-subscription (account principal))
    (ok (map-get? subscriptions account))
)

(define-read-only (is-subscription-active (account principal))
    (match (map-get? subscriptions account)
        sub (ok (<= stacks-block-time (get end-time sub)))
        (ok false)
    )
)

(define-read-only (get-tier-info (tier uint))
    (ok (map-get? subscription-tiers tier))
)

(define-public (set-tier (tier uint) (price uint) (duration uint) (benefits (string-utf8 256)))
    (begin
        (ok (map-set subscription-tiers tier {
            price: price,
            duration: duration,
            benefits: benefits
        }))
    )
)

(define-public (subscribe (tier uint))
    (let
        (
            (tier-info (unwrap! (map-get? subscription-tiers tier) ERR-NOT-FOUND))
            (current-time stacks-block-time)
        )
        (map-set subscriptions tx-sender {
            start-time: current-time,
            end-time: (+ current-time (get duration tier-info)),
            tier: tier,
            auto-renew: false
        })
        (try! (ft-mint? subscription-token u1 tx-sender))
        (ok true)
    )
)

(define-public (renew-subscription)
    (let
        (
            (sub (unwrap! (map-get? subscriptions tx-sender) ERR-NOT-FOUND))
            (tier-info (unwrap! (map-get? subscription-tiers (get tier sub)) ERR-NOT-FOUND))
            (current-time stacks-block-time)
        )
        (map-set subscriptions tx-sender (merge sub {
            end-time: (+ (get end-time sub) (get duration tier-info))
        }))
        (ok true)
    )
)

(define-public (cancel-subscription)
    (begin
        (asserts! (is-some (map-get? subscriptions tx-sender)) ERR-NOT-FOUND)
        (try! (ft-burn? subscription-token u1 tx-sender))
        (ok (map-delete subscriptions tx-sender))
    )
)

(define-public (toggle-auto-renew)
    (let
        (
            (sub (unwrap! (map-get? subscriptions tx-sender) ERR-NOT-FOUND))
        )
        (ok (map-set subscriptions tx-sender (merge sub {auto-renew: (not (get auto-renew sub))})))
    )
)

(define-public (transfer (amount uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (ft-transfer? subscription-token amount sender recipient)
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .subscription-token)
)
