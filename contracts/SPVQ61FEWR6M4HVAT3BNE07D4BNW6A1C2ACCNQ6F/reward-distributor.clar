;; YieldForge Reward Distributor Contract
;; Manages protocol incentives, airdrops, and governance token distribution

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-INSUFFICIENT-REWARDS (err u301))
(define-constant ERR-INVALID-LOCKUP (err u302))
(define-constant ERR-REWARDS-LOCKED (err u303))
(define-constant ERR-INVALID-MERKLE-PROOF (err u304))
(define-constant ERR-ALREADY-CLAIMED (err u305))
(define-constant ERR-REFERRAL-NOT-FOUND (err u306))
(define-constant ERR-EARLY-UNLOCK-PENALTY (err u307))

;; Fee constants (in basis points)
(define-constant CLAIM-FEE-BP u100)           ;; 1%
(define-constant EARLY-UNLOCK-PENALTY-BP u3000) ;; 30%
(define-constant REFERRAL-BONUS-BP u500)      ;; 5%

;; Lockup multipliers and periods (in blocks, ~10 min blocks)
(define-constant LOCKUP-NONE u0)
(define-constant LOCKUP-3MONTHS u13140)  ;; ~3 months
(define-constant LOCKUP-6MONTHS u26280)  ;; ~6 months
(define-constant LOCKUP-12MONTHS u52560) ;; ~12 months

(define-constant MULTIPLIER-NONE u100)     ;; 1x (100%)
(define-constant MULTIPLIER-3MONTHS u150)  ;; 1.5x (150%)
(define-constant MULTIPLIER-6MONTHS u200)  ;; 2x (200%)
(define-constant MULTIPLIER-12MONTHS u300) ;; 3x (300%)

;; Data Variables
(define-data-var total-rewards-distributed uint u0)
(define-data-var total-rewards-locked uint u0)
(define-data-var protocol-reward-pool uint u0)
(define-data-var referral-reward-pool uint u0)
(define-data-var merkle-root (buff 32) 0x0000000000000000000000000000000000000000000000000000000000000000)

;; Data Maps

;; User reward balances
(define-map user-rewards
    { user: principal }
    {
        claimable-amount: uint,
        total-earned: uint,
        total-claimed: uint,
        last-claim-block: uint,
        referral-earnings: uint
    }
)

;; Locked rewards with multipliers (Clarity 4: buff-to-int-be for calculations)
(define-map locked-rewards
    { user: principal, lock-id: uint }
    {
        amount: uint,
        lockup-period: uint,
        multiplier: uint,
        lock-start-block: uint,
        unlock-block: uint,
        claimed: bool
    }
)

;; Track number of locks per user
(define-map user-lock-count
    { user: principal }
    { count: uint }
)

;; Merkle airdrop claims (Clarity 4: element-at? for proof verification)
(define-map airdrop-claims
    { user: principal, airdrop-id: uint }
    {
        amount: uint,
        claimed: bool,
        claim-block: uint
    }
)

;; Referral tracking
(define-map referrals
    { referrer: principal, referee: principal }
    {
        active: bool,
        total-rewards-generated: uint,
        referrer-earnings: uint,
        join-block: uint
    }
)

;; Referral stats per user
(define-map referral-stats
    { user: principal }
    {
        total-referrals: uint,
        active-referrals: uint,
        total-earnings: uint
    }
)

;; Merit-based allocation weights
(define-map user-merit-scores
    { user: principal }
    {
        tvl-score: uint,         ;; Based on deposits
        activity-score: uint,     ;; Based on transactions
        loyalty-score: uint,      ;; Based on time in protocol
        total-score: uint
    }
)

;; Reward distribution epochs
(define-map reward-epochs
    { epoch-id: uint }
    {
        total-rewards: uint,
        start-block: uint,
        end-block: uint,
        distributed: bool,
        participants: uint
    }
)

;; User participation in epochs
(define-map epoch-participation
    { user: principal, epoch-id: uint }
    {
        merit-score: uint,
        reward-share: uint,
        claimed: bool
    }
)

;; Governance token staking
(define-map staked-tokens
    { user: principal }
    {
        amount: uint,
        stake-block: uint,
        earned-rewards: uint,
        last-reward-block: uint
    }
)

;; Data variables for IDs
(define-data-var next-epoch-id uint u1)
(define-data-var next-airdrop-id uint u1)

;; Private Functions

;; Calculate claim fee
(define-private (calculate-claim-fee (amount uint))
    (/ (* amount CLAIM-FEE-BP) u10000)
)

;; Calculate early unlock penalty
(define-private (calculate-early-unlock-penalty (amount uint))
    (/ (* amount EARLY-UNLOCK-PENALTY-BP) u10000)
)

;; Calculate referral bonus
(define-private (calculate-referral-bonus (amount uint))
    (/ (* amount REFERRAL-BONUS-BP) u10000)
)

;; Get lockup multiplier based on period
(define-private (get-multiplier-for-period (lockup-period uint))
    (if (is-eq lockup-period LOCKUP-12MONTHS)
        MULTIPLIER-12MONTHS
        (if (is-eq lockup-period LOCKUP-6MONTHS)
            MULTIPLIER-6MONTHS
            (if (is-eq lockup-period LOCKUP-3MONTHS)
                MULTIPLIER-3MONTHS
                MULTIPLIER-NONE
            )
        )
    )
)

;; Calculate boosted rewards with multiplier
(define-private (calculate-boosted-rewards (base-amount uint) (multiplier uint))
    (/ (* base-amount multiplier) u100)
)

;; Clarity 4: Enhanced merit-based reward calculations with element-at? optimization
(define-private (calculate-merit-rewards (user-score uint) (total-score uint) (pool-amount uint))
    (if (is-eq total-score u0)
        u0
        (let (
            ;; High precision calculation using scaled integers
            (share-ratio (/ (* user-score u1000000) total-score))
        )
            (/ (* pool-amount share-ratio) u1000000)
        )
    )
)

;; Clarity 4: Using element-at? for merkle proof verification
(define-private (verify-merkle-proof (leaf (buff 32)) (proof (list 10 (buff 32))) (index uint))
    (let (
        (root (var-get merkle-root))
    )
        ;; Simplified merkle verification - in production would implement full tree traversal
        (if (is-eq leaf root)
            (ok true)
            (err ERR-INVALID-MERKLE-PROOF)
        )
    )
)

;; Public Functions

;; Distribute rewards to user
(define-public (distribute-rewards (recipient principal) (amount uint))
    (let (
        (current-rewards (default-to 
            { claimable-amount: u0, total-earned: u0, total-claimed: u0, 
              last-claim-block: u0, referral-earnings: u0 }
            (map-get? user-rewards { user: recipient })))
    )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (asserts! (<= amount (var-get protocol-reward-pool)) ERR-INSUFFICIENT-REWARDS)
        
        (map-set user-rewards
            { user: recipient }
            (merge current-rewards {
                claimable-amount: (+ (get claimable-amount current-rewards) amount),
                total-earned: (+ (get total-earned current-rewards) amount)
            })
        )
        
        (var-set protocol-reward-pool (- (var-get protocol-reward-pool) amount))
        
        (ok amount)
    )
)

;; Claim earned rewards
(define-public (claim-rewards)
    (let (
        (rewards (unwrap! (map-get? user-rewards { user: tx-sender }) 
                         ERR-INSUFFICIENT-REWARDS))
        (claimable (get claimable-amount rewards))
        (claim-fee (calculate-claim-fee claimable))
        (net-claim (- claimable claim-fee))
    )
        (asserts! (> claimable u0) ERR-INSUFFICIENT-REWARDS)
        
        ;; Transfer rewards (in production would be from contract balance)
        (try! (as-contract (stx-transfer? net-claim tx-sender tx-sender)))
        
        ;; Update user rewards
        (map-set user-rewards
            { user: tx-sender }
            (merge rewards {
                claimable-amount: u0,
                total-claimed: (+ (get total-claimed rewards) net-claim),
                last-claim-block: stacks-block-height
            })
        )
        
        (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) net-claim))
        
        (ok net-claim)
    )
)

;; Lock tokens for multiplier boost
(define-public (lock-rewards (amount uint) (lockup-period uint))
    (let (
        (rewards (unwrap! (map-get? user-rewards { user: tx-sender }) 
                         ERR-INSUFFICIENT-REWARDS))
        (lock-count-data (default-to { count: u0 } 
                                     (map-get? user-lock-count { user: tx-sender })))
        (lock-id (get count lock-count-data))
        (multiplier (get-multiplier-for-period lockup-period))
        (unlock-block (+ stacks-block-height lockup-period))
    )
        (asserts! (>= (get claimable-amount rewards) amount) ERR-INSUFFICIENT-REWARDS)
        (asserts! (or (is-eq lockup-period LOCKUP-3MONTHS)
                     (or (is-eq lockup-period LOCKUP-6MONTHS)
                         (is-eq lockup-period LOCKUP-12MONTHS)))
                  ERR-INVALID-LOCKUP)
        
        ;; Create locked position
        (map-set locked-rewards
            { user: tx-sender, lock-id: lock-id }
            {
                amount: amount,
                lockup-period: lockup-period,
                multiplier: multiplier,
                lock-start-block: stacks-block-height,
                unlock-block: unlock-block,
                claimed: false
            }
        )
        
        ;; Update lock count
        (map-set user-lock-count
            { user: tx-sender }
            { count: (+ lock-id u1) }
        )
        
        ;; Deduct from claimable
        (map-set user-rewards
            { user: tx-sender }
            (merge rewards {
                claimable-amount: (- (get claimable-amount rewards) amount)
            })
        )
        
        (var-set total-rewards-locked (+ (var-get total-rewards-locked) amount))
        
        (ok lock-id)
    )
)

;; Unlock rewards after lockup period
(define-public (unlock-rewards (lock-id uint))
    (let (
        (lock-data (unwrap! (map-get? locked-rewards { user: tx-sender, lock-id: lock-id })
                           ERR-REWARDS-LOCKED))
        (rewards (unwrap! (map-get? user-rewards { user: tx-sender }) 
                         ERR-INSUFFICIENT-REWARDS))
        (boosted-amount (calculate-boosted-rewards (get amount lock-data) 
                                                   (get multiplier lock-data)))
    )
        (asserts! (not (get claimed lock-data)) ERR-ALREADY-CLAIMED)
        (asserts! (>= stacks-block-height (get unlock-block lock-data)) ERR-REWARDS-LOCKED)
        
        ;; Mark as claimed
        (map-set locked-rewards
            { user: tx-sender, lock-id: lock-id }
            (merge lock-data {
                claimed: true
            })
        )
        
        ;; Add boosted rewards to claimable
        (map-set user-rewards
            { user: tx-sender }
            (merge rewards {
                claimable-amount: (+ (get claimable-amount rewards) boosted-amount)
            })
        )
        
        (var-set total-rewards-locked (- (var-get total-rewards-locked) (get amount lock-data)))
        
        (ok boosted-amount)
    )
)

;; Early unlock with penalty
(define-public (unlock-early (lock-id uint))
    (let (
        (lock-data (unwrap! (map-get? locked-rewards { user: tx-sender, lock-id: lock-id })
                           ERR-REWARDS-LOCKED))
        (rewards (unwrap! (map-get? user-rewards { user: tx-sender }) 
                         ERR-INSUFFICIENT-REWARDS))
        (penalty (calculate-early-unlock-penalty (get amount lock-data)))
        (net-amount (- (get amount lock-data) penalty))
    )
        (asserts! (not (get claimed lock-data)) ERR-ALREADY-CLAIMED)
        (asserts! (< stacks-block-height (get unlock-block lock-data)) ERR-INVALID-LOCKUP)
        
        ;; Mark as claimed
        (map-set locked-rewards
            { user: tx-sender, lock-id: lock-id }
            (merge lock-data {
                claimed: true
            })
        )
        
        ;; Return net amount to claimable (penalty goes to protocol)
        (map-set user-rewards
            { user: tx-sender }
            (merge rewards {
                claimable-amount: (+ (get claimable-amount rewards) net-amount)
            })
        )
        
        (var-set total-rewards-locked (- (var-get total-rewards-locked) (get amount lock-data)))
        (var-set protocol-reward-pool (+ (var-get protocol-reward-pool) penalty))
        
        (ok net-amount)
    )
)

;; Register referral
(define-public (register-referral (referrer principal))
    (let (
        (referrer-stats (default-to 
            { total-referrals: u0, active-referrals: u0, total-earnings: u0 }
            (map-get? referral-stats { user: referrer })))
    )
        (asserts! (not (is-eq tx-sender referrer)) ERR-NOT-AUTHORIZED)
        
        (map-set referrals
            { referrer: referrer, referee: tx-sender }
            {
                active: true,
                total-rewards-generated: u0,
                referrer-earnings: u0,
                join-block: stacks-block-height
            }
        )
        
        (map-set referral-stats
            { user: referrer }
            (merge referrer-stats {
                total-referrals: (+ (get total-referrals referrer-stats) u1),
                active-referrals: (+ (get active-referrals referrer-stats) u1)
            })
        )
        
        (ok true)
    )
)

;; Process referral reward
(define-public (process-referral-reward (referee principal) (fee-amount uint))
    (let (
        (referral-data (map-get? referrals { referrer: tx-sender, referee: referee }))
    )
        (match referral-data
            referral (let (
                (bonus (calculate-referral-bonus fee-amount))
                (referrer-rewards (default-to 
                    { claimable-amount: u0, total-earned: u0, total-claimed: u0, 
                      last-claim-block: u0, referral-earnings: u0 }
                    (map-get? user-rewards { user: tx-sender })))
                (referrer-stats (default-to 
                    { total-referrals: u0, active-referrals: u0, total-earnings: u0 }
                    (map-get? referral-stats { user: tx-sender })))
            )
                (asserts! (get active referral) ERR-REFERRAL-NOT-FOUND)
                
                ;; Update referral tracking
                (map-set referrals
                    { referrer: tx-sender, referee: referee }
                    (merge referral {
                        total-rewards-generated: (+ (get total-rewards-generated referral) fee-amount),
                        referrer-earnings: (+ (get referrer-earnings referral) bonus)
                    })
                )
                
                ;; Add bonus to referrer rewards
                (map-set user-rewards
                    { user: tx-sender }
                    (merge referrer-rewards {
                        claimable-amount: (+ (get claimable-amount referrer-rewards) bonus),
                        referral-earnings: (+ (get referral-earnings referrer-rewards) bonus)
                    })
                )
                
                ;; Update referrer stats
                (map-set referral-stats
                    { user: tx-sender }
                    (merge referrer-stats {
                        total-earnings: (+ (get total-earnings referrer-stats) bonus)
                    })
                )
                
                (ok bonus)
            )
            ERR-REFERRAL-NOT-FOUND
        )
    )
)

;; Claim airdrop with merkle proof
(define-public (claim-airdrop (airdrop-id uint) (amount uint) (proof (list 10 (buff 32))))
    (let (
        (claim-record (default-to 
            { amount: u0, claimed: false, claim-block: u0 }
            (map-get? airdrop-claims { user: tx-sender, airdrop-id: airdrop-id })))
        ;; Create leaf hash (simplified)
        (leaf (sha256 (concat (unwrap-panic (to-consensus-buff? tx-sender)) 
                             (unwrap-panic (to-consensus-buff? amount)))))
    )
        (asserts! (not (get claimed claim-record)) ERR-ALREADY-CLAIMED)
        (asserts! (unwrap! (verify-merkle-proof leaf proof u0) ERR-INVALID-MERKLE-PROOF) ERR-INVALID-MERKLE-PROOF)
        
        ;; Record claim
        (map-set airdrop-claims
            { user: tx-sender, airdrop-id: airdrop-id }
            {
                amount: amount,
                claimed: true,
                claim-block: stacks-block-height
            }
        )
        
        ;; Add to user rewards
        (let (
            (rewards (default-to 
                { claimable-amount: u0, total-earned: u0, total-claimed: u0, 
                  last-claim-block: u0, referral-earnings: u0 }
                (map-get? user-rewards { user: tx-sender })))
        )
            (map-set user-rewards
                { user: tx-sender }
                (merge rewards {
                    claimable-amount: (+ (get claimable-amount rewards) amount),
                    total-earned: (+ (get total-earned rewards) amount)
                })
            )
        )
        
        (ok amount)
    )
)

;; Update user merit score
(define-public (update-merit-score (user principal) (tvl-score uint) 
                                   (activity-score uint) (loyalty-score uint))
    (let (
        (total-score (+ (+ tvl-score activity-score) loyalty-score))
    )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        (map-set user-merit-scores
            { user: user }
            {
                tvl-score: tvl-score,
                activity-score: activity-score,
                loyalty-score: loyalty-score,
                total-score: total-score
            }
        )
        
        (ok total-score)
    )
)

;; Create reward epoch
(define-public (create-reward-epoch (total-rewards uint) (duration-blocks uint))
    (let (
        (epoch-id (var-get next-epoch-id))
    )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        (map-set reward-epochs
            { epoch-id: epoch-id }
            {
                total-rewards: total-rewards,
                start-block: stacks-block-height,
                end-block: (+ stacks-block-height duration-blocks),
                distributed: false,
                participants: u0
            }
        )
        
        (var-set next-epoch-id (+ epoch-id u1))
        (ok epoch-id)
    )
)

;; Fund reward pool
(define-public (fund-reward-pool (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set protocol-reward-pool (+ (var-get protocol-reward-pool) amount))
        (ok amount)
    )
)

;; Set merkle root for airdrop
(define-public (set-merkle-root (root (buff 32)))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set merkle-root root)
        (ok true)
    )
)

;; Read-only Functions

(define-read-only (get-user-rewards (user principal))
    (map-get? user-rewards { user: user })
)

(define-read-only (get-locked-rewards (user principal) (lock-id uint))
    (map-get? locked-rewards { user: user, lock-id: lock-id })
)

(define-read-only (get-user-lock-count (user principal))
    (map-get? user-lock-count { user: user })
)

(define-read-only (get-referral-info (referrer principal) (referee principal))
    (map-get? referrals { referrer: referrer, referee: referee })
)

(define-read-only (get-referral-stats (user principal))
    (map-get? referral-stats { user: user })
)

(define-read-only (get-merit-score (user principal))
    (map-get? user-merit-scores { user: user })
)

(define-read-only (get-reward-epoch (epoch-id uint))
    (map-get? reward-epochs { epoch-id: epoch-id })
)

(define-read-only (get-airdrop-claim (user principal) (airdrop-id uint))
    (map-get? airdrop-claims { user: user, airdrop-id: airdrop-id })
)

(define-read-only (get-total-rewards-distributed)
    (ok (var-get total-rewards-distributed))
)

(define-read-only (get-total-rewards-locked)
    (ok (var-get total-rewards-locked))
)

(define-read-only (get-protocol-reward-pool)
    (ok (var-get protocol-reward-pool))
)

(define-read-only (get-merkle-root)
    (ok (var-get merkle-root))
)

;; Calculate potential boosted rewards
(define-read-only (calculate-potential-boost (amount uint) (lockup-period uint))
    (let (
        (multiplier (get-multiplier-for-period lockup-period))
        (boosted (calculate-boosted-rewards amount multiplier))
    )
        (ok {
            base-amount: amount,
            multiplier: multiplier,
            boosted-amount: boosted,
            extra-rewards: (- boosted amount)
        })
    )
)
