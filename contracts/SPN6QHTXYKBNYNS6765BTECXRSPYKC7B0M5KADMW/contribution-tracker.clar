;; Contribution Tracker Smart Contract
;; Enhanced contribution tracking with analytics and reward tiers

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u200))
(define-constant ERR-CAMPAIGN-NOT-FOUND (err u201))
(define-constant ERR-INVALID-AMOUNT (err u202))
(define-constant ERR-NO-CONTRIBUTION (err u203))
(define-constant ERR-ALREADY-REFUNDED (err u204))
(define-constant ERR-REFUND-NOT-AVAILABLE (err u205))
(define-constant ERR-TIER-NOT-FOUND (err u206))
(define-constant ERR-INVALID-TIER (err u207))

;; Contribution tiers for rewards
(define-constant TIER-BRONZE u1)
(define-constant TIER-SILVER u2)
(define-constant TIER-GOLD u3)
(define-constant TIER-PLATINUM u4)

;; Data variables
(define-data-var total-platform-contributions uint u0)
(define-data-var total-platform-backers uint u0)

;; Data maps

;; Detailed contribution records
(define-map contribution-details
    { campaign-id: uint, contributor: principal }
    {
        total-amount: uint,
        contribution-count: uint,
        first-contribution: uint,
        last-contribution: uint,
        refunded: bool,
        reward-tier: uint
    }
)

;; Campaign contribution summary
(define-map campaign-contributions
    uint
    {
        total-raised: uint,
        contributor-count: uint,
        contribution-count: uint,
        average-contribution: uint,
        largest-contribution: uint,
        largest-contributor: (optional principal)
    }
)

;; Individual contribution transactions
(define-map contribution-transactions
    { campaign-id: uint, contributor: principal, tx-index: uint }
    {
        amount: uint,
        timestamp: uint,
        block: uint
    }
)

;; Contributor global stats
(define-map contributor-stats
    principal
    {
        total-contributed: uint,
        campaigns-backed: uint,
        successful-campaigns: uint,
        refunds-received: uint
    }
)

;; Reward tiers for campaigns
(define-map campaign-reward-tiers
    { campaign-id: uint, tier: uint }
    {
        min-amount: uint,
        max-backers: uint,
        current-backers: uint,
        reward-description: (string-utf8 256)
    }
)

;; Refund tracking
(define-map refund-claims
    { campaign-id: uint, contributor: principal }
    {
        amount: uint,
        claimed-at: uint,
        processed: bool
    }
)

;; Private functions

(define-private (calculate-tier (amount uint) (campaign-id uint))
    (if (>= amount u10000000000) ;; 10,000 STX
        TIER-PLATINUM
        (if (>= amount u1000000000) ;; 1,000 STX
            TIER-GOLD
            (if (>= amount u100000000) ;; 100 STX
                TIER-SILVER
                TIER-BRONZE
            )
        )
    )
)

(define-private (update-contributor-global-stats (contributor principal) (amount uint))
    (let (
        (stats (default-to 
            { total-contributed: u0, campaigns-backed: u0, successful-campaigns: u0, refunds-received: u0 }
            (map-get? contributor-stats contributor)
        ))
    )
        (map-set contributor-stats contributor
            (merge stats {
                total-contributed: (+ (get total-contributed stats) amount)
            })
        )
    )
)

;; Read-only functions

(define-read-only (get-contribution-details (campaign-id uint) (contributor principal))
    (map-get? contribution-details { campaign-id: campaign-id, contributor: contributor })
)

(define-read-only (get-campaign-contribution-summary (campaign-id uint))
    (map-get? campaign-contributions campaign-id)
)

(define-read-only (get-contribution-transaction (campaign-id uint) (contributor principal) (tx-index uint))
    (map-get? contribution-transactions { 
        campaign-id: campaign-id, 
        contributor: contributor, 
        tx-index: tx-index 
    })
)

(define-read-only (get-contributor-stats (contributor principal))
    (default-to 
        { total-contributed: u0, campaigns-backed: u0, successful-campaigns: u0, refunds-received: u0 }
        (map-get? contributor-stats contributor)
    )
)

(define-read-only (get-reward-tier (campaign-id uint) (tier uint))
    (map-get? campaign-reward-tiers { campaign-id: campaign-id, tier: tier })
)

(define-read-only (get-refund-claim (campaign-id uint) (contributor principal))
    (map-get? refund-claims { campaign-id: campaign-id, contributor: contributor })
)

(define-read-only (get-platform-stats)
    (ok {
        total-contributions: (var-get total-platform-contributions),
        total-backers: (var-get total-platform-backers)
    })
)

(define-read-only (get-contributor-tier (campaign-id uint) (contributor principal))
    (match (get-contribution-details campaign-id contributor)
        details (ok (get reward-tier details))
        ERR-NO-CONTRIBUTION
    )
)

(define-read-only (is-top-contributor (campaign-id uint) (contributor principal))
    (match (get-campaign-contribution-summary campaign-id)
        summary 
            (match (get largest-contributor summary)
                top-contributor (ok (is-eq contributor top-contributor))
                (ok false)
            )
        (ok false)
    )
)

(define-read-only (get-contribution-history (campaign-id uint) (contributor principal) (limit uint))
    (ok (list 
        (get-contribution-transaction campaign-id contributor u1)
        (get-contribution-transaction campaign-id contributor u2)
        (get-contribution-transaction campaign-id contributor u3)
        (get-contribution-transaction campaign-id contributor u4)
        (get-contribution-transaction campaign-id contributor u5)
        (get-contribution-transaction campaign-id contributor u6)
        (get-contribution-transaction campaign-id contributor u7)
        (get-contribution-transaction campaign-id contributor u8)
        (get-contribution-transaction campaign-id contributor u9)
        (get-contribution-transaction campaign-id contributor u10)
    ))
)

;; Public functions

(define-public (record-contribution 
    (campaign-id uint) 
    (contributor principal) 
    (amount uint)
)
    (let (
        (existing-details (get-contribution-details campaign-id contributor))
        (campaign-summary (default-to 
            { 
                total-raised: u0, 
                contributor-count: u0, 
                contribution-count: u0,
                average-contribution: u0,
                largest-contribution: u0,
                largest-contributor: none
            }
            (map-get? campaign-contributions campaign-id)
        ))
    )
        ;; Validate
        (asserts! (> amount u0) ERR-INVALID-AMOUNT)
        
        ;; Update or create contribution details
        (match existing-details
            details 
                (let (
                    (new-total (+ (get total-amount details) amount))
                    (new-count (+ (get contribution-count details) u1))
                    (tier (calculate-tier new-total campaign-id))
                )
                    (map-set contribution-details 
                        { campaign-id: campaign-id, contributor: contributor }
                        (merge details {
                            total-amount: new-total,
                            contribution-count: new-count,
                            last-contribution: stacks-block-height,
                            reward-tier: tier
                        })
                    )
                    ;; Store transaction
                    (map-set contribution-transactions
                        { campaign-id: campaign-id, contributor: contributor, tx-index: new-count }
                        { amount: amount, timestamp: stacks-block-height, block: stacks-block-height }
                    )
                )
            (begin
                ;; New contributor
                (map-set contribution-details 
                    { campaign-id: campaign-id, contributor: contributor }
                    {
                        total-amount: amount,
                        contribution-count: u1,
                        first-contribution: stacks-block-height,
                        last-contribution: stacks-block-height,
                        refunded: false,
                        reward-tier: (calculate-tier amount campaign-id)
                    }
                )
                ;; Store first transaction
                (map-set contribution-transactions
                    { campaign-id: campaign-id, contributor: contributor, tx-index: u1 }
                    { amount: amount, timestamp: stacks-block-height, block: stacks-block-height }
                )
                ;; Increment platform backers for new contributor
                (var-set total-platform-backers (+ (var-get total-platform-backers) u1))
            )
        )
        
        ;; Update campaign summary
        (let (
            (new-total-raised (+ (get total-raised campaign-summary) amount))
            (new-contribution-count (+ (get contribution-count campaign-summary) u1))
            (new-contributor-count 
                (if (is-none existing-details)
                    (+ (get contributor-count campaign-summary) u1)
                    (get contributor-count campaign-summary)
                )
            )
            (is-largest (> amount (get largest-contribution campaign-summary)))
        )
            (map-set campaign-contributions campaign-id {
                total-raised: new-total-raised,
                contributor-count: new-contributor-count,
                contribution-count: new-contribution-count,
                average-contribution: (/ new-total-raised new-contribution-count),
                largest-contribution: (if is-largest amount (get largest-contribution campaign-summary)),
                largest-contributor: (if is-largest (some contributor) (get largest-contributor campaign-summary))
            })
        )
        
        ;; Update contributor global stats
        (update-contributor-global-stats contributor amount)
        
        ;; Update platform stats
        (var-set total-platform-contributions (+ (var-get total-platform-contributions) amount))
        
        (ok true)
    )
)

(define-public (claim-refund (campaign-id uint) (contributor principal) (amount uint))
    (let (
        (details (unwrap! (get-contribution-details campaign-id contributor) ERR-NO-CONTRIBUTION))
    )
        ;; Validate
        (asserts! (not (get refunded details)) ERR-ALREADY-REFUNDED)
        (asserts! (>= (get total-amount details) amount) ERR-INVALID-AMOUNT)
        
        ;; Record refund claim
        (map-set refund-claims 
            { campaign-id: campaign-id, contributor: contributor }
            {
                amount: amount,
                claimed-at: stacks-block-height,
                processed: true
            }
        )
        
        ;; Update contribution details
        (map-set contribution-details 
            { campaign-id: campaign-id, contributor: contributor }
            (merge details { refunded: true })
        )
        
        ;; Update contributor stats
        (let (
            (stats (get-contributor-stats contributor))
        )
            (map-set contributor-stats contributor
                (merge stats {
                    refunds-received: (+ (get refunds-received stats) amount)
                })
            )
        )
        
        (ok true)
    )
)

(define-public (add-reward-tier 
    (campaign-id uint)
    (tier uint)
    (min-amount uint)
    (max-backers uint)
    (reward-description (string-utf8 256))
)
    (begin
        ;; Validate tier
        (asserts! (<= tier TIER-PLATINUM) ERR-INVALID-TIER)
        (asserts! (>= tier TIER-BRONZE) ERR-INVALID-TIER)
        (asserts! (> min-amount u0) ERR-INVALID-AMOUNT)
        
        ;; Create reward tier
        (map-set campaign-reward-tiers 
            { campaign-id: campaign-id, tier: tier }
            {
                min-amount: min-amount,
                max-backers: max-backers,
                current-backers: u0,
                reward-description: reward-description
            }
        )
        
        (ok true)
    )
)

(define-public (increment-successful-campaigns (contributor principal))
    (let (
        (stats (get-contributor-stats contributor))
    )
        (map-set contributor-stats contributor
            (merge stats {
                successful-campaigns: (+ (get successful-campaigns stats) u1)
            })
        )
        (ok true)
    )
)

(define-public (increment-campaigns-backed (contributor principal))
    (let (
        (stats (get-contributor-stats contributor))
    )
        (map-set contributor-stats contributor
            (merge stats {
                campaigns-backed: (+ (get campaigns-backed stats) u1)
            })
        )
        (ok true)
    )
)

(define-public (get-contributions-by-campaign (campaign-id uint))
    (ok (get-campaign-contribution-summary campaign-id))
)

(define-public (update-campaign-summary (campaign-id uint) (total-raised uint) (contributor-count uint))
    (let (
        (summary (default-to 
            { 
                total-raised: u0, 
                contributor-count: u0, 
                contribution-count: u0,
                average-contribution: u0,
                largest-contribution: u0,
                largest-contributor: none
            }
            (map-get? campaign-contributions campaign-id)
        ))
    )
        (map-set campaign-contributions campaign-id
            (merge summary {
                total-raised: total-raised,
                contributor-count: contributor-count
            })
        )
        (ok true)
    )
)
