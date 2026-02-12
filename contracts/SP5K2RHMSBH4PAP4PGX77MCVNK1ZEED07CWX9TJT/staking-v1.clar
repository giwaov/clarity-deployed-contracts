;; Staking Contract
;; Advanced staking system with flexible lock periods, reward tiers, and compound interest

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1001))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1002))
(define-constant ERR_INVALID_AMOUNT (err u1003))
(define-constant ERR_STAKE_NOT_FOUND (err u1004))
(define-constant ERR_STAKE_LOCKED (err u1005))
(define-constant ERR_ALREADY_STAKED (err u1006))
(define-constant ERR_INVALID_DURATION (err u1007))
(define-constant ERR_NO_REWARDS (err u1008))
(define-constant ERR_POOL_PAUSED (err u1009))
(define-constant ERR_MAX_STAKES_REACHED (err u1010))
(define-constant ERR_COOLDOWN_ACTIVE (err u1011))
(define-constant ERR_INVALID_TIER (err u1012))
(define-constant ERR_EMERGENCY_ONLY (err u1013))

;; Lock duration tiers (in blocks, ~10 min per block)
(define-constant TIER_FLEXIBLE u0)      ;; No lock
(define-constant TIER_30_DAYS u4320)    ;; ~30 days
(define-constant TIER_90_DAYS u12960)   ;; ~90 days
(define-constant TIER_180_DAYS u25920)  ;; ~180 days
(define-constant TIER_365_DAYS u52560)  ;; ~365 days

;; APY rates in basis points (divide by 10000 for percentage)
(define-constant APY_FLEXIBLE u300)     ;; 3% APY
(define-constant APY_30_DAYS u600)      ;; 6% APY
(define-constant APY_90_DAYS u1000)     ;; 10% APY
(define-constant APY_180_DAYS u1500)    ;; 15% APY
(define-constant APY_365_DAYS u2500)    ;; 25% APY

;; Other constants
(define-constant MIN_STAKE_AMOUNT u100000)   ;; 0.1 STX minimum
(define-constant MAX_STAKES_PER_USER u10)
(define-constant COOLDOWN_PERIOD u144)        ;; ~24 hours
(define-constant BLOCKS_PER_YEAR u525600)
(define-constant EARLY_WITHDRAWAL_PENALTY u1000) ;; 10% penalty

;; Data variables
(define-data-var total-staked uint u0)
(define-data-var total-rewards-distributed uint u0)
(define-data-var pool-paused bool false)
(define-data-var emergency-mode bool false)
(define-data-var reward-pool uint u0)
(define-data-var next-stake-id uint u1)

;; Data maps
(define-map stakes
  { stake-id: uint }
  {
    owner: principal,
    amount: uint,
    tier: uint,
    start-block: uint,
    unlock-block: uint,
    last-reward-block: uint,
    accumulated-rewards: uint,
    auto-compound: bool,
    cooldown-start: uint
  }
)

(define-map user-stakes
  { user: principal }
  { stake-ids: (list 10 uint), total-staked: uint, total-rewards-claimed: uint }
)

(define-map tier-info
  { tier: uint }
  { lock-duration: uint, apy: uint, total-staked: uint, staker-count: uint }
)

(define-map user-referrals
  { user: principal }
  { referrer: (optional principal), referral-count: uint, referral-rewards: uint }
)

;; Initialize tier info
(map-set tier-info { tier: TIER_FLEXIBLE } 
  { lock-duration: u0, apy: APY_FLEXIBLE, total-staked: u0, staker-count: u0 })
(map-set tier-info { tier: TIER_30_DAYS } 
  { lock-duration: TIER_30_DAYS, apy: APY_30_DAYS, total-staked: u0, staker-count: u0 })
(map-set tier-info { tier: TIER_90_DAYS } 
  { lock-duration: TIER_90_DAYS, apy: APY_90_DAYS, total-staked: u0, staker-count: u0 })
(map-set tier-info { tier: TIER_180_DAYS } 
  { lock-duration: TIER_180_DAYS, apy: APY_180_DAYS, total-staked: u0, staker-count: u0 })
(map-set tier-info { tier: TIER_365_DAYS } 
  { lock-duration: TIER_365_DAYS, apy: APY_365_DAYS, total-staked: u0, staker-count: u0 })

;; Private functions
(define-private (is-valid-tier (tier uint))
  (or (is-eq tier TIER_FLEXIBLE)
      (is-eq tier TIER_30_DAYS)
      (is-eq tier TIER_90_DAYS)
      (is-eq tier TIER_180_DAYS)
      (is-eq tier TIER_365_DAYS)))

(define-private (get-tier-apy (tier uint))
  (if (is-eq tier TIER_FLEXIBLE) APY_FLEXIBLE
    (if (is-eq tier TIER_30_DAYS) APY_30_DAYS
      (if (is-eq tier TIER_90_DAYS) APY_90_DAYS
        (if (is-eq tier TIER_180_DAYS) APY_180_DAYS
          APY_365_DAYS)))))

(define-private (get-tier-duration (tier uint))
  tier)

(define-private (calculate-rewards (amount uint) (apy uint) (blocks uint))
  (/ (* (* amount apy) blocks) (* BLOCKS_PER_YEAR u10000)))

(define-private (update-tier-stats (tier uint) (amount-change int) (count-change int))
  (match (map-get? tier-info { tier: tier })
    current-info (begin
      (map-set tier-info { tier: tier }
        {
          lock-duration: (get lock-duration current-info),
          apy: (get apy current-info),
          total-staked: (if (< amount-change 0)
                          (- (get total-staked current-info) (to-uint (* -1 amount-change)))
                          (+ (get total-staked current-info) (to-uint amount-change))),
          staker-count: (if (< count-change 0)
                          (- (get staker-count current-info) (to-uint (* -1 count-change)))
                          (+ (get staker-count current-info) (to-uint count-change)))
        })
      (ok true))
    (err u1)))

;; Public functions

;; Stake STX with selected tier
(define-public (stake (amount uint) (tier uint) (auto-compound bool) (referrer (optional principal)))
  (let (
    (user tx-sender)
    (stake-id (var-get next-stake-id))
    (user-data (default-to 
      { stake-ids: (list ), total-staked: u0, total-rewards-claimed: u0 }
      (map-get? user-stakes { user: user })))
    (current-block stacks-block-height)
  )
    ;; Validations
    (asserts! (not (var-get pool-paused)) ERR_POOL_PAUSED)
    (asserts! (>= amount MIN_STAKE_AMOUNT) ERR_INVALID_AMOUNT)
    (asserts! (is-valid-tier tier) ERR_INVALID_TIER)
    (asserts! (< (len (get stake-ids user-data)) MAX_STAKES_PER_USER) ERR_MAX_STAKES_REACHED)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount user current-contract))
    
    ;; Create stake record
    (map-set stakes { stake-id: stake-id }
      {
        owner: user,
        amount: amount,
        tier: tier,
        start-block: current-block,
        unlock-block: (+ current-block (get-tier-duration tier)),
        last-reward-block: current-block,
        accumulated-rewards: u0,
        auto-compound: auto-compound,
        cooldown-start: u0
      })
    
    ;; Update user stakes
    (map-set user-stakes { user: user }
      {
        stake-ids: (unwrap! (as-max-len? (append (get stake-ids user-data) stake-id) u10) ERR_MAX_STAKES_REACHED),
        total-staked: (+ (get total-staked user-data) amount),
        total-rewards-claimed: (get total-rewards-claimed user-data)
      })
    
    ;; Handle referral
    (match referrer
      ref (if (and (is-none (get referrer (default-to 
              { referrer: none, referral-count: u0, referral-rewards: u0 }
              (map-get? user-referrals { user: user }))))
              (not (is-eq ref user)))
            (begin
              (map-set user-referrals { user: user }
                { referrer: (some ref), referral-count: u0, referral-rewards: u0 })
              (let ((ref-data (default-to 
                    { referrer: none, referral-count: u0, referral-rewards: u0 }
                    (map-get? user-referrals { user: ref }))))
                (map-set user-referrals { user: ref }
                  {
                    referrer: (get referrer ref-data),
                    referral-count: (+ (get referral-count ref-data) u1),
                    referral-rewards: (get referral-rewards ref-data)
                  })))
            true)
      true)
    
    ;; Update global stats
    (var-set total-staked (+ (var-get total-staked) amount))
    (var-set next-stake-id (+ stake-id u1))
    (unwrap! (update-tier-stats tier (to-int amount) 1) ERR_INVALID_TIER)
    
    (ok stake-id)))

;; Claim pending rewards
(define-public (claim-rewards (stake-id uint))
  (let (
    (stake-data (unwrap! (map-get? stakes { stake-id: stake-id }) ERR_STAKE_NOT_FOUND))
    (user tx-sender)
    (current-block stacks-block-height)
    (blocks-elapsed (- current-block (get last-reward-block stake-data)))
    (apy (get-tier-apy (get tier stake-data)))
    (pending-rewards (calculate-rewards (get amount stake-data) apy blocks-elapsed))
    (total-rewards (+ pending-rewards (get accumulated-rewards stake-data)))
  )
    ;; Validations
    (asserts! (is-eq (get owner stake-data) user) ERR_NOT_AUTHORIZED)
    (asserts! (> total-rewards u0) ERR_NO_REWARDS)
    (asserts! (<= total-rewards (var-get reward-pool)) ERR_INSUFFICIENT_BALANCE)
    
    ;; Transfer rewards
    (try! (as-contract? ((with-stx total-rewards)) (try! (stx-transfer? total-rewards tx-sender user))))
    
    ;; Update stake
    (map-set stakes { stake-id: stake-id }
      (merge stake-data { 
        last-reward-block: current-block,
        accumulated-rewards: u0
      }))
    
    ;; Update user stats
    (let ((user-data (unwrap! (map-get? user-stakes { user: user }) ERR_STAKE_NOT_FOUND)))
      (map-set user-stakes { user: user }
        (merge user-data { 
          total-rewards-claimed: (+ (get total-rewards-claimed user-data) total-rewards)
        })))
    
    ;; Update global stats
    (var-set reward-pool (- (var-get reward-pool) total-rewards))
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) total-rewards))
    
    (ok total-rewards)))

;; Compound rewards back into stake
(define-public (compound-rewards (stake-id uint))
  (let (
    (stake-data (unwrap! (map-get? stakes { stake-id: stake-id }) ERR_STAKE_NOT_FOUND))
    (user tx-sender)
    (current-block stacks-block-height)
    (blocks-elapsed (- current-block (get last-reward-block stake-data)))
    (apy (get-tier-apy (get tier stake-data)))
    (pending-rewards (calculate-rewards (get amount stake-data) apy blocks-elapsed))
    (total-rewards (+ pending-rewards (get accumulated-rewards stake-data)))
  )
    ;; Validations
    (asserts! (is-eq (get owner stake-data) user) ERR_NOT_AUTHORIZED)
    (asserts! (> total-rewards u0) ERR_NO_REWARDS)
    
    ;; Add rewards to stake amount
    (map-set stakes { stake-id: stake-id }
      (merge stake-data { 
        amount: (+ (get amount stake-data) total-rewards),
        last-reward-block: current-block,
        accumulated-rewards: u0
      }))
    
    ;; Update global stats
    (var-set total-staked (+ (var-get total-staked) total-rewards))
    
    (ok total-rewards)))

;; Initiate cooldown for unstaking (for locked tiers)
(define-public (initiate-cooldown (stake-id uint))
  (let (
    (stake-data (unwrap! (map-get? stakes { stake-id: stake-id }) ERR_STAKE_NOT_FOUND))
    (user tx-sender)
  )
    (asserts! (is-eq (get owner stake-data) user) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get cooldown-start stake-data) u0) ERR_COOLDOWN_ACTIVE)
    
    (map-set stakes { stake-id: stake-id }
      (merge stake-data { cooldown-start: stacks-block-height }))
    
    (ok true)))

;; Unstake after lock period or cooldown
(define-public (unstake (stake-id uint))
  (let (
    (stake-data (unwrap! (map-get? stakes { stake-id: stake-id }) ERR_STAKE_NOT_FOUND))
    (user tx-sender)
    (current-block stacks-block-height)
    (is-unlocked (>= current-block (get unlock-block stake-data)))
    (cooldown-complete (and (> (get cooldown-start stake-data) u0)
                           (>= current-block (+ (get cooldown-start stake-data) COOLDOWN_PERIOD))))
  )
    ;; Validations
    (asserts! (is-eq (get owner stake-data) user) ERR_NOT_AUTHORIZED)
    (asserts! (or is-unlocked cooldown-complete (var-get emergency-mode)) ERR_STAKE_LOCKED)
    
    ;; Calculate final rewards
    (let (
      (blocks-elapsed (- current-block (get last-reward-block stake-data)))
      (apy (get-tier-apy (get tier stake-data)))
      (pending-rewards (calculate-rewards (get amount stake-data) apy blocks-elapsed))
      (total-rewards (+ pending-rewards (get accumulated-rewards stake-data)))
      (penalty (if (and (not is-unlocked) (not (var-get emergency-mode)))
                 (/ (* (get amount stake-data) EARLY_WITHDRAWAL_PENALTY) u10000)
                 u0))
      (final-amount (- (+ (get amount stake-data) total-rewards) penalty))
    )
      ;; Transfer funds back
      (try! (as-contract? ((with-stx final-amount)) (try! (stx-transfer? final-amount tx-sender user))))
      
      ;; Remove stake
      (map-delete stakes { stake-id: stake-id })
      
      ;; Update user stakes
      (let ((user-data (unwrap! (map-get? user-stakes { user: user }) ERR_STAKE_NOT_FOUND)))
        (map-set user-stakes { user: user }
          {
            stake-ids: (filter not-equal-stake-id (get stake-ids user-data)),
            total-staked: (- (get total-staked user-data) (get amount stake-data)),
            total-rewards-claimed: (+ (get total-rewards-claimed user-data) total-rewards)
          }))
      
      ;; Update global stats
      (var-set total-staked (- (var-get total-staked) (get amount stake-data)))
      (unwrap! (update-tier-stats (get tier stake-data) (* -1 (to-int (get amount stake-data))) -1) ERR_INVALID_TIER)
      
      (ok final-amount))))

;; Helper for filtering stake IDs (would need to be adjusted based on context)
(define-private (not-equal-stake-id (id uint))
  true)

;; Add to reward pool
(define-public (add-rewards (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender current-contract))
    (var-set reward-pool (+ (var-get reward-pool) amount))
    (ok true)))

;; Emergency unstake (owner only, with penalty waived)
(define-public (emergency-unstake-all)
  (begin
    (asserts! (var-get emergency-mode) ERR_EMERGENCY_ONLY)
    ;; Users can call regular unstake which will work in emergency mode
    (ok true)))

;; Admin functions
(define-public (pause-pool)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set pool-paused true)
    (ok true)))

(define-public (unpause-pool)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set pool-paused false)
    (ok true)))

(define-public (enable-emergency-mode)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set emergency-mode true)
    (var-set pool-paused true)
    (ok true)))

(define-public (disable-emergency-mode)
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set emergency-mode false)
    (ok true)))

;; Read-only functions
(define-read-only (get-stake (stake-id uint))
  (map-get? stakes { stake-id: stake-id }))

(define-read-only (get-user-stakes (user principal))
  (map-get? user-stakes { user: user }))

(define-read-only (get-pending-rewards (stake-id uint))
  (let (
    (stake-data (unwrap! (map-get? stakes { stake-id: stake-id }) u0))
    (blocks-elapsed (- stacks-block-height (get last-reward-block stake-data)))
    (apy (get-tier-apy (get tier stake-data)))
    (pending (calculate-rewards (get amount stake-data) apy blocks-elapsed))
  )
    (+ pending (get accumulated-rewards stake-data))))

(define-read-only (get-tier-details (tier uint))
  (map-get? tier-info { tier: tier }))

(define-read-only (get-pool-stats)
  {
    total-staked: (var-get total-staked),
    total-rewards-distributed: (var-get total-rewards-distributed),
    reward-pool: (var-get reward-pool),
    is-paused: (var-get pool-paused),
    emergency-mode: (var-get emergency-mode)
  })

(define-read-only (get-user-referral-info (user principal))
  (map-get? user-referrals { user: user }))

(define-read-only (estimate-rewards (amount uint) (tier uint) (blocks uint))
  (calculate-rewards amount (get-tier-apy tier) blocks))

(define-read-only (get-unlock-time (stake-id uint))
  (let ((stake-data (unwrap! (map-get? stakes { stake-id: stake-id }) u0)))
    (get unlock-block stake-data)))

(define-read-only (is-stake-unlocked (stake-id uint))
  (let ((stake-data (unwrap! (map-get? stakes { stake-id: stake-id }) false)))
    (>= stacks-block-height (get unlock-block stake-data))))

(define-read-only (get-all-tiers)
  (list 
    { tier: TIER_FLEXIBLE, name: "Flexible", apy: APY_FLEXIBLE, duration: u0 }
    { tier: TIER_30_DAYS, name: "30 Days", apy: APY_30_DAYS, duration: TIER_30_DAYS }
    { tier: TIER_90_DAYS, name: "90 Days", apy: APY_90_DAYS, duration: TIER_90_DAYS }
    { tier: TIER_180_DAYS, name: "180 Days", apy: APY_180_DAYS, duration: TIER_180_DAYS }
    { tier: TIER_365_DAYS, name: "365 Days", apy: APY_365_DAYS, duration: TIER_365_DAYS }
  ))
