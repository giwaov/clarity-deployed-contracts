;; title: rewards-distributor
;; version: 1.0.0
;; summary: Token incentives for users who view ads
;; description: User rewards, vesting schedules, multipliers, bonus campaigns, and referral rewards

;; constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-rewards-locked (err u103))
(define-constant err-invalid-tier (err u104))
(define-constant err-already-claimed (err u105))
(define-constant err-campaign-inactive (err u106))

;; Reward tiers
(define-constant TIER-BRONZE u1)
(define-constant TIER-SILVER u2)
(define-constant TIER-GOLD u3)
(define-constant TIER-PLATINUM u4)

;; data vars
(define-data-var base-reward-per-view uint u1000) ;; Base reward in micro-tokens
(define-data-var vesting-duration uint u4320) ;; ~30 days in blocks
(define-data-var total-rewards-distributed uint u0)
(define-data-var total-rewards-pending uint u0)
(define-data-var min-claim-amount uint u10000)

;; data maps
(define-map user-rewards
    { user: principal }
    {
        pending: uint,
        claimed: uint,
        total-earned: uint,
        tier: uint,
        multiplier: uint, ;; 100 = 1x, 150 = 1.5x
        last-claim: uint
    }
)

(define-map reward-tiers
    { tier: uint }
    {
        name: (string-ascii 20),
        multiplier: uint,
        min-views: uint,
        benefits: (string-utf8 200)
    }
)

(define-map vesting-schedules
    { user: principal, vest-id: uint }
    {
        amount: uint,
        unlock-time: uint,
        claimed: bool
    }
)

(define-map vest-count
    { user: principal }
    {
        total: uint
    }
)

(define-map reward-campaigns
    { campaign-id: uint }
    {
        bonus-rate: uint, ;; Percentage bonus
        start-time: uint,
        end-time: uint,
        budget: uint,
        spent: uint,
        active: bool
    }
)

(define-map referral-rewards
    { referrer: principal }
    {
        total-referrals: uint,
        rewards-earned: uint,
        pending-rewards: uint
    }
)

(define-map claim-history
    { user: principal, claim-id: uint }
    {
        amount: uint,
        timestamp: uint
    }
)

;; private functions
(define-private (get-tier-multiplier (tier uint))
    (if (is-eq tier TIER-PLATINUM) u200
        (if (is-eq tier TIER-GOLD) u150
            (if (is-eq tier TIER-SILVER) u120
                u100
            )
        )
    )
)

(define-private (calculate-reward (base uint) (multiplier uint))
    (/ (* base multiplier) u100)
)

;; read only functions
(define-read-only (get-user-rewards (user principal))
    (map-get? user-rewards { user: user })
)

(define-read-only (get-tier-info (tier uint))
    (map-get? reward-tiers { tier: tier })
)

(define-read-only (get-vesting-schedule (user principal) (vest-id uint))
    (map-get? vesting-schedules { user: user, vest-id: vest-id })
)

(define-read-only (get-vest-count (user principal))
    (default-to { total: u0 } (map-get? vest-count { user: user }))
)

(define-read-only (get-reward-campaign (campaign-id uint))
    (map-get? reward-campaigns { campaign-id: campaign-id })
)

(define-read-only (get-referral-rewards (referrer principal))
    (map-get? referral-rewards { referrer: referrer })
)

(define-read-only (get-claim-history (user principal) (claim-id uint))
    (map-get? claim-history { user: user, claim-id: claim-id })
)

;; public functions
(define-public (calculate-user-reward (user principal) (base-amount uint))
    (let
        (
            (user-data (default-to
                { pending: u0, claimed: u0, total-earned: u0, tier: TIER-BRONZE, multiplier: u100, last-claim: u0 }
                (map-get? user-rewards { user: user })
            ))
            (tier-multiplier (get-tier-multiplier (get tier user-data)))
            (reward (calculate-reward base-amount tier-multiplier))
        )
        (ok reward)
    )
)

(define-public (add-reward
    (user principal)
    (amount uint)
    (with-vesting bool)
)
    (let
        (
            (user-data (default-to
                { pending: u0, claimed: u0, total-earned: u0, tier: TIER-BRONZE, multiplier: u100, last-claim: u0 }
                (map-get? user-rewards { user: user })
            ))
        )
        (if with-vesting
            (let
                (
                    (count-data (get-vest-count user))
                    (vest-id (+ (get total count-data) u1))
                    (unlock-time (+ stacks-block-time (var-get vesting-duration)))
                )
                (map-set vesting-schedules
                    { user: user, vest-id: vest-id }
                    {
                        amount: amount,
                        unlock-time: unlock-time,
                        claimed: false
                    }
                )
                (map-set vest-count { user: user } { total: vest-id })
            )
            (map-set user-rewards
                { user: user }
                (merge user-data {
                    pending: (+ (get pending user-data) amount),
                    total-earned: (+ (get total-earned user-data) amount)
                })
            )
        )

        (var-set total-rewards-pending (+ (var-get total-rewards-pending) amount))
        (ok true)
    )
)

(define-public (claim-rewards)
    (let
        (
            (user-data (unwrap! (map-get? user-rewards { user: tx-sender }) err-not-found))
            (claim-amount (get pending user-data))
        )
        (asserts! (>= claim-amount (var-get min-claim-amount)) err-insufficient-balance)

        ;; In production, transfer tokens to user
        ;; (try! (as-contract (stx-transfer? claim-amount tx-sender tx-sender)))

        (map-set user-rewards
            { user: tx-sender }
            (merge user-data {
                pending: u0,
                claimed: (+ (get claimed user-data) claim-amount),
                last-claim: stacks-block-time
            })
        )

        (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) claim-amount))
        (var-set total-rewards-pending (- (var-get total-rewards-pending) claim-amount))

        (ok claim-amount)
    )
)

(define-public (claim-vested-reward (vest-id uint))
    (let
        (
            (vest-data (unwrap! (map-get? vesting-schedules { user: tx-sender, vest-id: vest-id }) err-not-found))
        )
        (asserts! (>= stacks-block-time (get unlock-time vest-data)) err-rewards-locked)
        (asserts! (not (get claimed vest-data)) err-already-claimed)

        ;; In production, transfer tokens to user
        ;; (try! (as-contract (stx-transfer? (get amount vest-data) tx-sender tx-sender)))

        (map-set vesting-schedules
            { user: tx-sender, vest-id: vest-id }
            (merge vest-data { claimed: true })
        )

        (let
            (
                (user-data (unwrap! (map-get? user-rewards { user: tx-sender }) err-not-found))
            )
            (map-set user-rewards
                { user: tx-sender }
                (merge user-data {
                    claimed: (+ (get claimed user-data) (get amount vest-data))
                })
            )
        )

        (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) (get amount vest-data)))
        (ok (get amount vest-data))
    )
)

(define-public (upgrade-tier (user principal) (new-tier uint))
    (let
        (
            (user-data (unwrap! (map-get? user-rewards { user: user }) err-not-found))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (and (>= new-tier TIER-BRONZE) (<= new-tier TIER-PLATINUM)) err-invalid-tier)

        (map-set user-rewards
            { user: user }
            (merge user-data {
                tier: new-tier,
                multiplier: (get-tier-multiplier new-tier)
            })
        )
        (ok true)
    )
)

(define-public (create-bonus-campaign
    (campaign-id uint)
    (bonus-rate uint)
    (duration uint)
    (budget uint)
)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)

        (map-set reward-campaigns
            { campaign-id: campaign-id }
            {
                bonus-rate: bonus-rate,
                start-time: stacks-block-time,
                end-time: (+ stacks-block-time duration),
                budget: budget,
                spent: u0,
                active: true
            }
        )
        (ok true)
    )
)

(define-public (add-referral-reward (referrer principal) (amount uint))
    (let
        (
            (referral-data (default-to
                { total-referrals: u0, rewards-earned: u0, pending-rewards: u0 }
                (map-get? referral-rewards { referrer: referrer })
            ))
        )
        (map-set referral-rewards
            { referrer: referrer }
            {
                total-referrals: (+ (get total-referrals referral-data) u1),
                rewards-earned: (+ (get rewards-earned referral-data) amount),
                pending-rewards: (+ (get pending-rewards referral-data) amount)
            }
        )
        (ok true)
    )
)

(define-public (claim-referral-rewards)
    (let
        (
            (referral-data (unwrap! (map-get? referral-rewards { referrer: tx-sender }) err-not-found))
            (claim-amount (get pending-rewards referral-data))
        )
        (asserts! (> claim-amount u0) err-insufficient-balance)

        ;; In production, transfer tokens to referrer
        ;; (try! (as-contract (stx-transfer? claim-amount tx-sender tx-sender)))

        (map-set referral-rewards
            { referrer: tx-sender }
            (merge referral-data { pending-rewards: u0 })
        )

        (ok claim-amount)
    )
)

;; Admin functions
(define-public (set-base-reward (new-reward uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set base-reward-per-view new-reward)
        (ok true)
    )
)

(define-public (set-vesting-duration (new-duration uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (var-set vesting-duration new-duration)
        (ok true)
    )
)

(define-public (initialize-tiers)
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)

        (map-set reward-tiers { tier: TIER-BRONZE } {
            name: "Bronze",
            multiplier: u100,
            min-views: u0,
            benefits: u"Base rewards"
        })

        (map-set reward-tiers { tier: TIER-SILVER } {
            name: "Silver",
            multiplier: u120,
            min-views: u100,
            benefits: u"20% bonus rewards"
        })

        (map-set reward-tiers { tier: TIER-GOLD } {
            name: "Gold",
            multiplier: u150,
            min-views: u500,
            benefits: u"50% bonus rewards + early access"
        })

        (map-set reward-tiers { tier: TIER-PLATINUM } {
            name: "Platinum",
            multiplier: u200,
            min-views: u1000,
            benefits: u"100% bonus rewards + premium features"
        })

        (ok true)
    )
)
