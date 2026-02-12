;; Liquidity Incentives Contract for Predinex
;; Manages on-chain tracking and distribution of incentive bonuses
;; Rewards early bettors, volume contributors, and loyal participants

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-UNAUTHORIZED (err u401))
(define-constant ERR-INVALID-AMOUNT (err u400))
(define-constant ERR-POOL-NOT-FOUND (err u404))
(define-constant ERR-INCENTIVE-NOT-FOUND (err u405))
(define-constant ERR-ALREADY-CLAIMED (err u410))
(define-constant ERR-INSUFFICIENT-BALANCE (err u424))
(define-constant ERR-INVALID-CONFIG (err u422))
(define-constant ERR-CLAIM-WINDOW-CLOSED (err u413))
(define-constant ERR-INVALID-POOL-STATE (err u414))
(define-constant ERR-INCENTIVE-DISABLED (err u415))
(define-constant ERR-MINIMUM-BET-NOT-MET (err u405))
(define-constant ERR-MAX-CLAIMS-REACHED (err u406))
(define-constant ERR-LEADERBOARD-UPDATE-FAILED (err u407))
(define-constant ERR-VESTING-NOT-MET (err u408))

;; Incentive configuration constants
(define-constant EARLY-BIRD-BONUS-PERCENT u5) ;; 5% bonus for first bettors
(define-constant EARLY-BIRD-THRESHOLD u10) ;; First 10 bettors
(define-constant VOLUME-BONUS-PERCENT u2) ;; 2% bonus when threshold reached
(define-constant VOLUME-THRESHOLD u1000000) ;; 1000 STX in microstacks
(define-constant REFERRAL-BONUS-PERCENT u2) ;; 2% referral bonus
(define-constant LOYALTY-BONUS-PERCENT u5) ;; 0.5% per previous bet, max 5%
(define-constant MAX-BONUS-PER-BET u100000000) ;; Max 100 STX bonus
(define-constant CLAIM-WINDOW-BLOCKS u2016) ;; 2 weeks to claim incentives
(define-constant MINIMUM-BET-AMOUNT u1000000) ;; 1 STX minimum bet for incentives
(define-constant MAX-CLAIMS-PER-USER u100)
(define-constant BONUS-MULTIPLIER-CAP u10)
(define-constant STREAK-BONUS-THRESHOLD u5)

;; [NEW] Tier Constants
(define-constant TIER-BRONZE u0)
(define-constant TIER-SILVER u1)
(define-constant TIER-GOLD u2)
(define-constant TIER-PLATINUM u3)

;; [NEW] Reputation Constants
(define-constant REPUTATION-THRESHOLD-LOW u50)
(define-constant REPUTATION-THRESHOLD-HIGH u150)

;; [NEW] Global Caps
(define-constant GLOBAL-DAILY-CAP u10000000000) ;; 10,000 STX daily cap
(define-constant GLOBAL-WEEKLY-CAP u50000000000) ;; 50,000 STX weekly cap

;; [NEW] Staking Constants
(define-constant MIN-STAKE-AMOUNT u10000000) ;; 10 STX min stake
(define-constant STAKE-PERIOD-BLOCKS u1440) ;; ~10 days staking period

;; [NEW] Error Constants
(define-constant ERR-USER-NOT-FOUND (err u413))
(define-constant ERR-INSUFFICIENT-REPUTATION (err u414))
(define-constant ERR-TIER-NOT-MET (err u415))
(define-constant ERR-STAKE-NOT-FOUND (err u416))
(define-constant ERR-STAKE-LOCKED (err u417))
(define-constant ERR-GLOBAL-CAP-REACHED (err u418))
(define-constant ERR-SYBIL-COOLDOWN (err u419))

;; Data structures
(define-map incentive-configs
  { pool-id: uint }
  {
    early-bird-enabled: bool,
    volume-bonus-enabled: bool,
    referral-enabled: bool,
    loyalty-enabled: bool,
    total-incentives-allocated: uint,
    total-incentives-claimed: uint,
    created-at: uint
  }
)

(define-map user-incentives
  { pool-id: uint, user: principal, incentive-type: (string-ascii 32) }
  {
    amount: uint,
    status: (string-ascii 16),
    earned-at: uint,
    claimed-at: (optional uint),
    claim-deadline: uint,
    bonus-multiplier: uint,
    streak-count: uint,
    is-premium: bool
  }
)

(define-map pool-bet-tracking
  { pool-id: uint, user: principal }
  {
    bet-count: uint,
    total-bet-amount: uint,
    first-bet-at: uint,
    last-bet-at: uint,
    consecutive-bets: uint,
    highest-bet: uint,
    average-bet: uint,
    claims-count: uint
  }
)

;; [NEW] Leaderboard Tracking
(define-map pool-leaderboards
  { pool-id: uint }
  { 
    top-earners: (list 10 principal),
    last-updated: uint
  }
)

(define-map leaderboard-entries
  { pool-id: uint, user: principal }
  { 
    total-earned: uint,
    rank: (optional uint)
  }
)

(define-map pool-incentive-stats
  { pool-id: uint }
  {
    total-early-bird-bonuses: uint,
    total-volume-bonuses: uint,
    total-referral-bonuses: uint,
    total-loyalty-bonuses: uint,
    total-bettors-rewarded: uint,
    early-bird-count: uint,
    streak-bonuses-awarded: uint,
    premium-bonuses-awarded: uint,
    average-bonus-amount: uint,
    peak-activity-block: uint,
    remaining-budget: uint
  }
)

;; [NEW] Global Records
(define-map global-leaderboard
  { user: principal }
  { total-earned: uint, last-earned-at: uint }
)

(define-map user-tiers
  { user: principal }
  { tier: uint, multiplier: uint, total-volume: uint }
)

(define-map user-reputation
  { user: principal }
  { score: uint, rank: (string-ascii 16), last-updated: uint }
)

(define-map user-stakes
  { user: principal }
  { amount: uint, block-locked: uint, active: bool }
)

(define-map referral-badges
  { user: principal }
  { bronze-badge: bool, silver-badge: bool, gold-badge: bool, platinum-badge: bool }
)

(define-map oracle-reliability
  { oracle: principal }
  { successful-resolutions: uint, total-resolutions: uint, reliability-score: uint }
)

;; [NEW] Dynamic Bonus Rates
(define-map pool-bonus-rates
  { pool-id: uint }
  {
    early-bird-percent: uint,
    volume-percent: uint,
    referral-percent: uint,
    loyalty-percent: uint
  }
)

(define-map referral-tracking
  { referrer: principal, referred-user: principal, pool-id: uint }
  {
    referral-amount: uint,
    bonus-earned: uint,
    claimed: bool,
    referral-tier: uint,
    bonus-multiplier: uint,
    created-at: uint
  }
)

(define-map user-loyalty-history
  { user: principal }
  {
    total-pools-participated: uint,
    total-bets-placed: uint,
    total-incentives-earned: uint,
    total-incentives-claimed: uint
  }
)

;; Data variables
(define-data-var total-incentives-distributed uint u0)
(define-data-var total-incentives-claimed uint u0)
(define-data-var active-pools-with-incentives uint u0)
(define-data-var contract-balance uint u0)
(define-data-var total-unique-users uint u0)
(define-data-var highest-single-bonus uint u0)
(define-data-var contract-paused bool false)
(define-data-var emergency-mode bool false)
(define-data-var authorized-contract principal tx-sender)

;; [NEW] Global Spend Tracking
(define-data-var global-daily-spend uint u0)
(define-data-var global-weekly-spend uint u0)
(define-data-var last-spend-reset-block uint u0)

;; [NEW] Oracle Registry
(define-data-var total-oracles-tracked uint u0)

;; Initialize incentive configuration for a pool
(define-public (initialize-pool-incentives (pool-id uint))
  (begin
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-eq contract-caller (var-get authorized-contract))) ERR-UNAUTHORIZED)
    (asserts! (not (var-get contract-paused)) ERR-INVALID-POOL-STATE)
    (asserts! (> pool-id u0) ERR-INVALID-AMOUNT)
    
    (map-insert incentive-configs
      { pool-id: pool-id }
      {
        early-bird-enabled: true,
        volume-bonus-enabled: true,
        referral-enabled: true,
        loyalty-enabled: true,
        total-incentives-allocated: u0,
        total-incentives-claimed: u0,
        created-at: burn-block-height
      }
    )
    
    (var-set active-pools-with-incentives (+ (var-get active-pools-with-incentives) u1))
    (ok pool-id)
  )
)

;; Record a bet and calculate early bird bonus
(define-public (record-bet-and-calculate-early-bird (pool-id uint) (user principal) (bet-amount uint))
  (let (
    (config (unwrap! (map-get? incentive-configs { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
    (bet-tracking (default-to 
      { bet-count: u0, total-bet-amount: u0, first-bet-at: burn-block-height, last-bet-at: burn-block-height, consecutive-bets: u0, highest-bet: u0, average-bet: u0, claims-count: u0 }
      (map-get? pool-bet-tracking { pool-id: pool-id, user: user })
    ))
    (current-bet-count (get bet-count bet-tracking))
    (new-bet-count (+ current-bet-count u1))
    (new-total-amount (+ (get total-bet-amount bet-tracking) bet-amount))
    (new-average (if (> new-bet-count u0) (/ new-total-amount new-bet-count) u0))
    (new-highest (if (> bet-amount (get highest-bet bet-tracking)) bet-amount (get highest-bet bet-tracking)))
  )
    ;; Validate inputs
    (asserts! (is-eq contract-caller (var-get authorized-contract)) ERR-UNAUTHORIZED)
    (asserts! (get early-bird-enabled config) ERR-INCENTIVE-DISABLED)
    (asserts! (>= bet-amount MINIMUM-BET-AMOUNT) ERR-MINIMUM-BET-NOT-MET)
    (asserts! (not (var-get contract-paused)) ERR-INVALID-POOL-STATE)
    
    ;; Update bet tracking with enhanced metrics
    (begin
      (update-user-tier user bet-amount)
      (map-set pool-bet-tracking
        { pool-id: pool-id, user: user }
        {
          bet-count: new-bet-count,
          total-bet-amount: new-total-amount,
          first-bet-at: (get first-bet-at bet-tracking),
          last-bet-at: burn-block-height,
          consecutive-bets: (+ (get consecutive-bets bet-tracking) u1),
          highest-bet: new-highest,
          average-bet: new-average,
          claims-count: (get claims-count bet-tracking)
        }
      )
    )
    
    ;; Calculate early bird bonus if eligible
    (if (and (get early-bird-enabled config) (<= new-bet-count EARLY-BIRD-THRESHOLD))
      (let (
        (base-early-bird (calculate-enhanced-early-bird-bonus pool-id bet-amount new-bet-count))
        (tier-info (default-to { tier: TIER-BRONZE, multiplier: u1, total-volume: u0 } (map-get? user-tiers { user: user })))
        (tier-multiplier (get multiplier tier-info))
        (stake-multiplier (calculate-staking-multiplier user))
        (final-bonus (* (* base-early-bird tier-multiplier) stake-multiplier))
      )
        (if (and (> final-bonus u0) (validate-global-spend final-bonus))
          (begin
            (record-spend final-bonus)
            (update-global-leaderboard user final-bonus)
            (update-reputation user 10)
            (map-set user-incentives
              { pool-id: pool-id, user: user, incentive-type: "early-bird" }
              {
                amount: final-bonus,
                status: "pending",
                earned-at: burn-block-height,
                claimed-at: none,
                claim-deadline: (+ burn-block-height CLAIM-WINDOW-BLOCKS),
                bonus-multiplier: (* tier-multiplier stake-multiplier),
                streak-count: (get consecutive-bets bet-tracking),
                is-premium: (>= tier-multiplier u2)
              }
            )
            
            (update-user-leaderboard-entry pool-id user final-bonus)
            (update-enhanced-pool-stats pool-id "early-bird" final-bonus)
            (ok final-bonus)
          )
          (ok u0)
        )
      )
      (ok u0)
    )
  )
)

;; Calculate and award volume bonus when threshold is reached
(define-public (award-volume-bonus (pool-id uint) (user principal) (current-pool-volume uint))
  (let (
    (config (unwrap! (map-get? incentive-configs { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
    (bet-tracking (unwrap! (map-get? pool-bet-tracking { pool-id: pool-id, user: user }) ERR-POOL-NOT-FOUND))
  )
    ;; Validate volume bonus is enabled and threshold reached
    (asserts! (get volume-bonus-enabled config) ERR-INVALID-CONFIG)
    (asserts! (>= current-pool-volume VOLUME-THRESHOLD) ERR-INVALID-AMOUNT)
    
    ;; Check if user already claimed volume bonus for this pool
    (asserts! (is-none (map-get? user-incentives { pool-id: pool-id, user: user, incentive-type: "volume" })) ERR-ALREADY-CLAIMED)
    
    (let ((volume-bonus (calculate-volume-bonus pool-id (get total-bet-amount bet-tracking))))
      (if (> volume-bonus u0)
        (begin
          (map-set user-incentives
            { pool-id: pool-id, user: user, incentive-type: "volume" }
            {
              amount: volume-bonus,
              status: "pending",
              earned-at: burn-block-height,
              claimed-at: none,
              claim-deadline: (+ burn-block-height CLAIM-WINDOW-BLOCKS),
              bonus-multiplier: u1,
              streak-count: u0,
              is-premium: false
            }
          )
          (update-user-leaderboard-entry pool-id user volume-bonus)
          (update-pool-stats pool-id "volume" volume-bonus)
          (ok volume-bonus)
        )
        (ok u0)
      )
    )
  )
)

;; Award referral bonus when referred user places bet
(define-public (award-referral-bonus (referrer principal) (referred-user principal) (pool-id uint) (referred-bet-amount uint))
  (let (
    (config (unwrap! (map-get? incentive-configs { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
  )
    ;; Validate referral is enabled
    (asserts! (get referral-enabled config) ERR-INVALID-CONFIG)
    (asserts! (not (is-eq referrer referred-user)) ERR-INVALID-AMOUNT)
    (asserts! (> referred-bet-amount u0) ERR-INVALID-AMOUNT)
    
    (let (
      (base-referral (calculate-referral-bonus pool-id referred-bet-amount))
      (tier-info (default-to { tier: TIER-BRONZE, multiplier: u1, total-volume: u0 } (map-get? user-tiers { user: referrer })))
      (tier-multiplier (get multiplier tier-info))
      (final-bonus (* base-referral tier-multiplier))
    )
      (if (and (> final-bonus u0) (validate-global-spend final-bonus))
        (begin
          (record-spend final-bonus)
          (update-global-leaderboard referrer final-bonus)
          (update-reputation referrer 5) ;; Referrer gets reputation
          (map-insert referral-tracking
            { referrer: referrer, referred-user: referred-user, pool-id: pool-id }
            {
              referral-amount: referred-bet-amount,
              bonus-earned: final-bonus,
              claimed: false,
              referral-tier: (get tier tier-info),
              bonus-multiplier: tier-multiplier,
              created-at: burn-block-height
            }
          )
          
          ;; Award bonus to referrer
          (map-set user-incentives
            { pool-id: pool-id, user: referrer, incentive-type: "referral" }
            {
              amount: final-bonus,
              status: "pending",
              earned-at: burn-block-height,
              claimed-at: none,
              claim-deadline: (+ burn-block-height CLAIM-WINDOW-BLOCKS),
              bonus-multiplier: tier-multiplier,
              streak-count: u0,
              is-premium: (>= tier-multiplier u2)
            }
          )
          
          (update-user-leaderboard-entry pool-id referrer final-bonus)
          (update-pool-stats pool-id "referral" final-bonus)
          (ok final-bonus)
        )
        (ok u0)
      )
    )
  )
)

;; Award loyalty bonus for repeat bettors
(define-public (award-loyalty-bonus (pool-id uint) (user principal) (current-bet-amount uint))
  (let (
    (config (unwrap! (map-get? incentive-configs { pool-id: pool-id }) ERR-POOL-NOT-FOUND))
    (loyalty-history (default-to 
      { total-pools-participated: u0, total-bets-placed: u0, total-incentives-earned: u0, total-incentives-claimed: u0 }
      (map-get? user-loyalty-history { user: user })
    ))
    (previous-bets (get total-bets-placed loyalty-history))
  )
    ;; Validate loyalty bonus is enabled
    (asserts! (get loyalty-enabled config) ERR-INVALID-CONFIG)
    (asserts! (> previous-bets u0) ERR-INVALID-AMOUNT)
    
    ;; Check if user already claimed loyalty bonus for this pool
    (asserts! (is-none (map-get? user-incentives { pool-id: pool-id, user: user, incentive-type: "loyalty" })) ERR-ALREADY-CLAIMED)
    
    (let ((loyalty-bonus (calculate-loyalty-bonus pool-id current-bet-amount previous-bets)))
      (if (> loyalty-bonus u0)
        (begin
          (map-set user-incentives
            { pool-id: pool-id, user: user, incentive-type: "loyalty" }
            {
              amount: loyalty-bonus,
              status: "pending",
              earned-at: burn-block-height,
              claimed-at: none,
              claim-deadline: (+ burn-block-height CLAIM-WINDOW-BLOCKS),
              bonus-multiplier: u1,
              streak-count: u0,
              is-premium: false
            }
          )
          
          (update-user-leaderboard-entry pool-id user loyalty-bonus)
          (update-pool-stats pool-id "loyalty" loyalty-bonus)
          (ok loyalty-bonus)
        )
        (ok u0)
      )
    )
  )
)

;; Claim pending incentive bonus
(define-public (claim-incentive (pool-id uint) (incentive-type (string-ascii 32)))
  (let (
    (incentive (unwrap! 
      (map-get? user-incentives { pool-id: pool-id, user: tx-sender, incentive-type: incentive-type })
      ERR-INCENTIVE-NOT-FOUND
    ))
  )
    ;; Validate incentive is pending
    (asserts! (is-eq (get status incentive) "pending") ERR-ALREADY-CLAIMED)
    
    ;; Validate claim window is still open
    (asserts! (< burn-block-height (get claim-deadline incentive)) ERR-CLAIM-WINDOW-CLOSED)
    
    ;; Enforce vesting schedule
    (let ((vesting (calculate-vesting-schedule (get earned-at incentive) (get amount incentive))))
      (asserts! (get fully-vested vesting) ERR-VESTING-NOT-MET)
      
      ;; Validate contract has sufficient balance
      (asserts! (>= (var-get contract-balance) (get amount incentive)) ERR-INSUFFICIENT-BALANCE)
    )
    
    (let ((claim-amount (get amount incentive)))
      ;; Update incentive status
      (map-set user-incentives
        { pool-id: pool-id, user: tx-sender, incentive-type: incentive-type }
        (merge incentive {
          status: "claimed",
          claimed-at: (some burn-block-height)
        })
      )
      
      ;; Update contract balance
      (var-set contract-balance (- (var-get contract-balance) claim-amount))
      
      ;; Update total claimed
      (var-set total-incentives-claimed (+ (var-get total-incentives-claimed) claim-amount))
      
      ;; Update pool stats
      (let ((config (unwrap! (map-get? incentive-configs { pool-id: pool-id }) ERR-POOL-NOT-FOUND)))
        (map-set incentive-configs
          { pool-id: pool-id }
          (merge config {
            total-incentives-claimed: (+ (get total-incentives-claimed config) claim-amount)
          })
        )
      )
      
      ;; Transfer STX to user (simulated - in production would use stx-transfer?)
      (ok claim-amount)
    )
  )
)

;; Deposit funds into contract for incentive distribution
(define-public (deposit-incentive-funds (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    ;; Update contract balance
    (var-set contract-balance (+ (var-get contract-balance) amount))
    
    (ok amount)
  )
)

;; [NEW] Protocol Fee Rebate
(define-public (claim-fee-rebate (pool-id uint))
  (let ((tier (default-to { tier: TIER-BRONZE, multiplier: u1, total-volume: u0 } (map-get? user-tiers { user: tx-sender }))))
    (asserts! (>= (get tier tier) TIER-GOLD) ERR-TIER-NOT-MET)
    ;; Logic to calculate and transfer rebate (placeholder for internal balance update)
    (ok true)
  )
)

;; [NEW] Emergency User Exit
(define-public (emergency-burn-withdrawal (pool-id uint) (incentive-type (string-ascii 32)))
  (let ((incentive (unwrap! (map-get? user-incentives { pool-id: pool-id, user: tx-sender, incentive-type: incentive-type }) ERR-INCENTIVE-NOT-FOUND)))
    (asserts! (var-get emergency-mode) ERR-UNAUTHORIZED)
    ;; Allow withdrawal with 50% penalty during emergency
    (let ((withdrawal-amount (/ (get amount incentive) u2)))
      (map-set user-incentives { pool-id: pool-id, user: tx-sender, incentive-type: incentive-type } (merge incentive { status: "claimed" }))
      (ok withdrawal-amount)
    )
  )
)

;; [NEW] Batch Distribution
(define-public (batch-distribute-rewards (pool-id uint) (users (list 100 principal)) (amounts (list 100 uint)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    ;; Implementation logic would iterate and map-set
    (ok true)
  )
)


;; Withdraw unclaimed incentives (owner only)
(define-public (withdraw-unclaimed-incentives (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    (asserts! (>= (var-get contract-balance) amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Update contract balance
    (var-set contract-balance (- (var-get contract-balance) amount))
    
    (ok amount)
  )
)

;; Emergency pause contract (owner only)
(define-public (pause-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set contract-paused true)
    (ok true)
  )
)

;; Resume contract operations (owner only)
(define-public (resume-contract)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set contract-paused false)
    (ok true)
  )
)

;; Enable emergency mode (owner only)
(define-public (enable-emergency-mode)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set emergency-mode true)
    (var-set contract-paused true)
    (ok true)
  )
)

;; Disable emergency mode (owner only)
(define-public (disable-emergency-mode)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set emergency-mode false)
    (var-set contract-paused false)
    (ok true)
  )
)

(define-public (set-authorized-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (var-set authorized-contract contract)
    (ok true)
  )
)

;; Batch claim multiple incentives for efficiency
(define-public (batch-claim-incentives (pool-id uint) (incentive-types (list 10 (string-ascii 32))))
  (let (
    (total-claimed (fold batch-claim-helper incentive-types { pool-id: pool-id, user: tx-sender, total: u0 }))
  )
    (ok (get total total-claimed))
  )
)

;; Helper function for batch claiming
(define-private (batch-claim-helper (incentive-type (string-ascii 32)) (context { pool-id: uint, user: principal, total: uint }))
  (let (
    (pool-id (get pool-id context))
    (user (get user context))
    (current-total (get total context))
  )
    (match (claim-incentive pool-id incentive-type)
      success (merge context { total: (+ current-total success) })
      error context
    )
  )
)

;; Helper functions

(define-private (min (a uint) (b uint))
  (if (<= a b) a b)
)

;; Calculate early bird bonus
(define-private (calculate-early-bird-bonus (pool-id uint) (bet-amount uint))
  (let (
    (rates (default-to { early-bird-percent: EARLY-BIRD-BONUS-PERCENT, volume-percent: VOLUME-BONUS-PERCENT, referral-percent: REFERRAL-BONUS-PERCENT, loyalty-percent: LOYALTY-BONUS-PERCENT } (map-get? pool-bonus-rates { pool-id: pool-id })))
    (bonus (/ (* bet-amount (get early-bird-percent rates)) u100))
  )
    (if (> bonus MAX-BONUS-PER-BET)
      MAX-BONUS-PER-BET
      bonus
    )
  )
)

;; Calculate enhanced early bird bonus with position-based multiplier
(define-private (calculate-enhanced-early-bird-bonus (pool-id uint) (bet-amount uint) (position uint))
  (let (
    (rates (default-to { early-bird-percent: EARLY-BIRD-BONUS-PERCENT, volume-percent: VOLUME-BONUS-PERCENT, referral-percent: REFERRAL-BONUS-PERCENT, loyalty-percent: LOYALTY-BONUS-PERCENT } (map-get? pool-bonus-rates { pool-id: pool-id })))
    (base-bonus (/ (* bet-amount (get early-bird-percent rates)) u100))
    (position-multiplier (if (<= position u3) u3 (if (<= position u5) u2 u1)))
    (enhanced-bonus (/ (* base-bonus position-multiplier) u1))
  )
    (if (> enhanced-bonus MAX-BONUS-PER-BET)
      MAX-BONUS-PER-BET
      enhanced-bonus
    )
  )
)

;; Calculate bonus multiplier based on bet count
(define-private (calculate-bonus-multiplier (bet-count uint))
  (if (<= bet-count u3)
    u3
    (if (<= bet-count u7)
      u2
      u1
    )
  )
)

;; Calculate volume bonus
(define-private (calculate-volume-bonus (pool-id uint) (user-bet-amount uint))
  (let (
    (rates (default-to { early-bird-percent: EARLY-BIRD-BONUS-PERCENT, volume-percent: VOLUME-BONUS-PERCENT, referral-percent: REFERRAL-BONUS-PERCENT, loyalty-percent: LOYALTY-BONUS-PERCENT } (map-get? pool-bonus-rates { pool-id: pool-id })))
    (bonus (/ (* user-bet-amount (get volume-percent rates)) u100))
  )
    (if (> bonus MAX-BONUS-PER-BET)
      MAX-BONUS-PER-BET
      bonus
    )
  )
)

;; Calculate referral bonus
(define-private (calculate-referral-bonus (pool-id uint) (referred-bet-amount uint))
  (let (
    (rates (default-to { early-bird-percent: EARLY-BIRD-BONUS-PERCENT, volume-percent: VOLUME-BONUS-PERCENT, referral-percent: REFERRAL-BONUS-PERCENT, loyalty-percent: LOYALTY-BONUS-PERCENT } (map-get? pool-bonus-rates { pool-id: pool-id })))
    (bonus (/ (* referred-bet-amount (get referral-percent rates)) u100))
  )
    (if (> bonus MAX-BONUS-PER-BET)
      MAX-BONUS-PER-BET
      bonus
    )
  )
)

;; [NEW] Update Global Leaderboard
(define-private (update-global-leaderboard (user principal) (amount uint))
  (let (
    (entry (default-to { total-earned: u0, last-earned-at: u0 } (map-get? global-leaderboard { user: user })))
    (new-total (+ (get total-earned entry) amount))
  )
    (map-set global-leaderboard { user: user } { total-earned: new-total, last-earned-at: burn-block-height })
  )
)

;; [NEW] Update User Tier based on volume
(define-private (update-user-tier (user principal) (new-bet-amount uint))
  (let (
    (current-data (default-to { tier: TIER-BRONZE, multiplier: u1, total-volume: u0 } (map-get? user-tiers { user: user })))
    (new-volume (+ (get total-volume current-data) new-bet-amount))
    (new-tier (if (>= new-volume u1000000000) TIER-PLATINUM 
                (if (>= new-volume u500000000) TIER-GOLD 
                  (if (>= new-volume u100000000) TIER-SILVER TIER-BRONZE))))
    (new-multiplier (if (is-eq new-tier TIER-PLATINUM) u4
                      (if (is-eq new-tier TIER-GOLD) u3
                        (if (is-eq new-tier TIER-SILVER) u2 u1))))
  )
    (map-set user-tiers { user: user } { tier: new-tier, multiplier: new-multiplier, total-volume: new-volume })
  )
)

;; [NEW] Update User Reputation
(define-private (update-reputation (user principal) (points int))
  (let (
    (current-rep (default-to { score: u0, rank: "Newbie", last-updated: u0 } (map-get? user-reputation { user: user })))
    (current-score (get score current-rep))
    (new-score (if (>= points 0) 
                 (+ current-score (to-uint points))
                 (if (>= current-score (to-uint (- points))) 
                   (- current-score (to-uint (- points))) 
                   u0)))
    (new-rank (if (>= new-score REPUTATION-THRESHOLD-HIGH) "Expert"
                (if (>= new-score REPUTATION-THRESHOLD-LOW) "Pro" "Regular")))
  )
    (map-set user-reputation { user: user } { score: new-score, rank: new-rank, last-updated: burn-block-height })
  )
)

;; [NEW] Staking Logic
(define-public (stake-incentives (amount uint))
  (begin
    (asserts! (>= amount MIN-STAKE-AMOUNT) ERR-INVALID-AMOUNT)
    (asserts! (not (var-get contract-paused)) ERR-UNAUTHORIZED)
    (map-set user-stakes { user: tx-sender } { amount: amount, block-locked: (+ burn-block-height STAKE-PERIOD-BLOCKS), active: true })
    (ok true)
  )
)

(define-public (unstake-incentives)
  (let ((stake (unwrap! (map-get? user-stakes { user: tx-sender }) ERR-STAKE-NOT-FOUND)))
    (asserts! (>= burn-block-height (get block-locked stake)) ERR-STAKE-LOCKED)
    (map-set user-stakes { user: tx-sender } (merge stake { active: false }))
    (ok true)
  )
)

(define-private (calculate-staking-multiplier (user principal))
  (match (map-get? user-stakes { user: user })
    stake (if (get active stake) u2 u1)
    u1
  )
)

;; [NEW] Multi-Level Referral
(define-private (calculate-secondary-referral-bonus (pool-id uint) (bet-amount uint))
  (let ((base-bonus (calculate-referral-bonus pool-id bet-amount)))
    (/ base-bonus u2) ;; Secondary referrer gets 50% of base referral bonus
  )
)
(define-private (update-user-leaderboard-entry (pool-id uint) (user principal) (bonus-amount uint))
  (let (
    (entry (default-to { total-earned: u0, rank: none } (map-get? leaderboard-entries { pool-id: pool-id, user: user })))
    (new-total (+ (get total-earned entry) bonus-amount))
  )
    (map-set leaderboard-entries { pool-id: pool-id, user: user } (merge entry { total-earned: new-total }))
    (update-pool-leaderboard pool-id user new-total)
  )
)

(define-private (update-pool-leaderboard (pool-id uint) (user principal) (new-total uint))
  (let (
    (leaderboard (default-to { top-earners: (list), last-updated: u0 } (map-get? pool-leaderboards { pool-id: pool-id })))
    (current-top (get top-earners leaderboard))
  )
    ;; Simplified logic: If user not in list, append. If in list, do nothing (score updated in leaderboard-entries)
    ;; Sorting will be handled by read-only function for now to save gas on write
    (if (is-none (index-of current-top user))
      (if (< (len current-top) u10)
        (map-set pool-leaderboards { pool-id: pool-id } (merge leaderboard { top-earners: (unwrap-panic (as-max-len? (append current-top user) u10)), last-updated: burn-block-height }))
        true
      )
      true
    )
  )
)

;; [NEW] Oracle Reliability Tracking
(define-private (track-oracle-resolution (oracle principal) (success bool))
  (let ((current (default-to { successful-resolutions: u0, total-resolutions: u0, reliability-score: u0 } (map-get? oracle-reliability { oracle: oracle }))))
    (let (
      (new-total (+ (get total-resolutions current) u1))
      (new-success (if success (+ (get successful-resolutions current) u1) (get successful-resolutions current)))
      (new-score (/ (* new-success u100) new-total))
    )
      (map-set oracle-reliability { oracle: oracle } { successful-resolutions: new-success, total-resolutions: new-total, reliability-score: new-score })
    )
  )
)

;; [NEW] Global Spend Validation
(define-private (validate-global-spend (amount uint))
  (let (
    (daily (var-get global-daily-spend))
    (weekly (var-get global-weekly-spend))
  )
    (if (or (> (+ daily amount) GLOBAL-DAILY-CAP) (> (+ weekly amount) GLOBAL-WEEKLY-CAP))
      false
      true
    )
  )
)

(define-private (record-spend (amount uint))
  (begin
    (var-set global-daily-spend (+ (var-get global-daily-spend) amount))
    (var-set global-weekly-spend (+ (var-get global-weekly-spend) amount))
    true
  )
)

;; [NEW] Anti-Sybil Cooldown
(define-private (check-sybil-cooldown (user principal))
  (let ((loyalty (map-get? user-loyalty-history { user: user })))
    (match loyalty
      history (>= (get total-bets-placed history) u1) ;; Simple: must have at least 1 bet
      false
    )
  )
)
(define-private (calculate-loyalty-bonus (pool-id uint) (current-bet-amount uint) (previous-bets uint))
  (let (
    (rates (default-to { early-bird-percent: EARLY-BIRD-BONUS-PERCENT, volume-percent: VOLUME-BONUS-PERCENT, referral-percent: REFERRAL-BONUS-PERCENT, loyalty-percent: LOYALTY-BONUS-PERCENT } (map-get? pool-bonus-rates { pool-id: pool-id })))
    (base-loyalty-percent (get loyalty-percent rates))
    (bonus-percent (if (> previous-bets u10) base-loyalty-percent (/ (* previous-bets base-loyalty-percent) u10)))
    (bonus (/ (* current-bet-amount bonus-percent) u100))
  )
    (if (> bonus MAX-BONUS-PER-BET)
      MAX-BONUS-PER-BET
      bonus
    )
  )
)

;; Update pool statistics
(define-private (update-pool-stats (pool-id uint) (bonus-type (string-ascii 32)) (bonus-amount uint))
  (let (
    (stats (default-to 
      { total-early-bird-bonuses: u0, total-volume-bonuses: u0, total-referral-bonuses: u0, total-loyalty-bonuses: u0, total-bettors-rewarded: u0, early-bird-count: u0, streak-bonuses-awarded: u0, premium-bonuses-awarded: u0, average-bonus-amount: u0, peak-activity-block: u0, remaining-budget: u0 }
      (map-get? pool-incentive-stats { pool-id: pool-id })
    ))
  )
    (if (is-eq bonus-type "early-bird")
      (map-set pool-incentive-stats
        { pool-id: pool-id }
        (merge stats {
          total-early-bird-bonuses: (+ (get total-early-bird-bonuses stats) bonus-amount),
          early-bird-count: (+ (get early-bird-count stats) u1),
          peak-activity-block: burn-block-height
        })
      )
      (if (is-eq bonus-type "volume")
        (map-set pool-incentive-stats
          { pool-id: pool-id }
          (merge stats {
            total-volume-bonuses: (+ (get total-volume-bonuses stats) bonus-amount),
            peak-activity-block: burn-block-height
          })
        )
        (if (is-eq bonus-type "referral")
          (map-set pool-incentive-stats
            { pool-id: pool-id }
            (merge stats {
              total-referral-bonuses: (+ (get total-referral-bonuses stats) bonus-amount),
              peak-activity-block: burn-block-height
            })
          )
          (map-set pool-incentive-stats
            { pool-id: pool-id }
            (merge stats {
              total-loyalty-bonuses: (+ (get total-loyalty-bonuses stats) bonus-amount),
              peak-activity-block: burn-block-height
            })
          )
        )
      )
    )
  )
)

;; Enhanced update pool statistics with additional metrics
(define-private (update-enhanced-pool-stats (pool-id uint) (bonus-type (string-ascii 32)) (bonus-amount uint))
  (let (
    (stats (default-to 
      { total-early-bird-bonuses: u0, total-volume-bonuses: u0, total-referral-bonuses: u0, total-loyalty-bonuses: u0, total-bettors-rewarded: u0, early-bird-count: u0, streak-bonuses-awarded: u0, premium-bonuses-awarded: u0, average-bonus-amount: u0, peak-activity-block: u0, remaining-budget: u0 }
      (map-get? pool-incentive-stats { pool-id: pool-id })
    ))
    (total-bonuses (+ (+ (+ (get total-early-bird-bonuses stats) (get total-volume-bonuses stats)) (get total-referral-bonuses stats)) (get total-loyalty-bonuses stats)))
    (total-count (+ (+ (+ (get early-bird-count stats) u1) (get streak-bonuses-awarded stats)) (get premium-bonuses-awarded stats)))
    (new-average (if (> total-count u0) (/ (+ total-bonuses bonus-amount) total-count) u0))
  )
    ;; Update highest single bonus if applicable
    (if (> bonus-amount (var-get highest-single-bonus))
      (var-set highest-single-bonus bonus-amount)
      true
    )
    
    (if (is-eq bonus-type "early-bird")
      (map-set pool-incentive-stats
        { pool-id: pool-id }
        (merge stats {
          total-early-bird-bonuses: (+ (get total-early-bird-bonuses stats) bonus-amount),
          early-bird-count: (+ (get early-bird-count stats) u1),
          average-bonus-amount: new-average,
          peak-activity-block: burn-block-height
        })
      )
      (if (is-eq bonus-type "volume")
        (map-set pool-incentive-stats
          { pool-id: pool-id }
          (merge stats {
            total-volume-bonuses: (+ (get total-volume-bonuses stats) bonus-amount),
            average-bonus-amount: new-average,
            peak-activity-block: burn-block-height
          })
        )
        (if (is-eq bonus-type "referral")
          (map-set pool-incentive-stats
            { pool-id: pool-id }
            (merge stats {
              total-referral-bonuses: (+ (get total-referral-bonuses stats) bonus-amount),
              average-bonus-amount: new-average,
              peak-activity-block: burn-block-height
            })
          )
          (if (is-eq bonus-type "streak")
            (map-set pool-incentive-stats
              { pool-id: pool-id }
              (merge stats {
                streak-bonuses-awarded: (+ (get streak-bonuses-awarded stats) u1),
                average-bonus-amount: new-average,
                peak-activity-block: burn-block-height
              })
            )
            (map-set pool-incentive-stats
              { pool-id: pool-id }
              (merge stats {
                total-loyalty-bonuses: (+ (get total-loyalty-bonuses stats) bonus-amount),
                average-bonus-amount: new-average,
                peak-activity-block: burn-block-height
              })
            )
          )
        )
      )
    )
  )
)

;; Read-only functions

;; Get incentive configuration for a pool
(define-read-only (get-pool-incentive-config (pool-id uint))
  (map-get? incentive-configs { pool-id: pool-id })
)

;; Get user's pending incentive
(define-read-only (get-user-incentive (pool-id uint) (user principal) (incentive-type (string-ascii 32)))
  (map-get? user-incentives { pool-id: pool-id, user: user, incentive-type: incentive-type })
)

;; Get pool incentive statistics
(define-read-only (get-pool-incentive-stats (pool-id uint))
  (map-get? pool-incentive-stats { pool-id: pool-id })
)

;; Get user's bet tracking
(define-read-only (get-user-bet-tracking (pool-id uint) (user principal))
  (map-get? pool-bet-tracking { pool-id: pool-id, user: user })
)

;; Get user's loyalty history
(define-read-only (get-user-loyalty-history (user principal))
  (map-get? user-loyalty-history { user: user })
)

;; Get total incentives distributed
(define-read-only (get-total-incentives-distributed)
  (var-get total-incentives-distributed)
)

;; Get total incentives claimed
(define-read-only (get-total-incentives-claimed)
  (var-get total-incentives-claimed)
)

;; Get contract balance
(define-read-only (get-contract-balance)
  (var-get contract-balance)
)

;; Get active pools with incentives
(define-read-only (get-active-pools-count)
  (var-get active-pools-with-incentives)
)

;; Calculate total pending incentives for a user across all types
(define-read-only (get-user-total-pending-incentives (pool-id uint) (user principal))
  (let (
    (early-bird (match (map-get? user-incentives { pool-id: pool-id, user: user, incentive-type: "early-bird" })
      incentive (if (is-eq (get status incentive) "pending") (get amount incentive) u0)
      u0
    ))
    (volume (match (map-get? user-incentives { pool-id: pool-id, user: user, incentive-type: "volume" })
      incentive (if (is-eq (get status incentive) "pending") (get amount incentive) u0)
      u0
    ))
    (referral (match (map-get? user-incentives { pool-id: pool-id, user: user, incentive-type: "referral" })
      incentive (if (is-eq (get status incentive) "pending") (get amount incentive) u0)
      u0
    ))
    (loyalty (match (map-get? user-incentives { pool-id: pool-id, user: user, incentive-type: "loyalty" })
      incentive (if (is-eq (get status incentive) "pending") (get amount incentive) u0)
      u0
    ))
  )
    (+ early-bird volume referral loyalty)
  )
)

;; [ENHANCEMENT] Pool incentive configuration validation
(define-read-only (validate-pool-incentive-config (pool-id uint))
  (match (map-get? incentive-configs { pool-id: pool-id })
    config (ok {
      is-configured: true,
      early-bird-enabled: (get early-bird-enabled config),
      volume-bonus-enabled: (get volume-bonus-enabled config),
      referral-enabled: (get referral-enabled config),
      loyalty-enabled: (get loyalty-enabled config)
    })
    (err ERR-POOL-NOT-FOUND)
  )
)

;; [ENHANCEMENT] Check if user is eligible for early bird bonus
(define-read-only (is-early-bird-eligible (pool-id uint) (user principal))
  (match (map-get? pool-bet-tracking { pool-id: pool-id, user: user })
    bet-tracking (let ((bet-count (get bet-count bet-tracking)))
      (and (<= bet-count EARLY-BIRD-THRESHOLD) (> bet-count u0))
    )
    false
  )
)

;; [ENHANCEMENT] Check if user qualifies for volume bonus
(define-read-only (is-volume-bonus-eligible (pool-id uint) (user principal) (pool-volume uint))
  (and
    (>= pool-volume VOLUME-THRESHOLD)
    (is-none (map-get? user-incentives { pool-id: pool-id, user: user, incentive-type: "volume" }))
  )
)

;; [ENHANCEMENT] Check if referral bonus can be awarded
(define-read-only (can-award-referral-bonus (referrer principal) (referred-user principal) (pool-id uint))
  (and
    (not (is-eq referrer referred-user))
    (is-none (map-get? referral-tracking { referrer: referrer, referred-user: referred-user, pool-id: pool-id }))
  )
)

;; [ENHANCEMENT] Check if user qualifies for loyalty bonus
(define-read-only (is-loyalty-bonus-eligible (pool-id uint) (user principal))
  (match (map-get? user-loyalty-history { user: user })
    history (> (get total-bets-placed history) u0)
    false
  )
)

;; [ENHANCEMENT] Check if incentive claim window is still open
(define-read-only (is-claim-window-open (pool-id uint) (user principal) (incentive-type (string-ascii 32)))
  (match (map-get? user-incentives { pool-id: pool-id, user: user, incentive-type: incentive-type })
    incentive (< burn-block-height (get claim-deadline incentive))
    false
  )
)

;; [ENHANCEMENT] Calculate total incentives allocated for a pool
(define-read-only (get-pool-total-incentives-allocated (pool-id uint))
  (match (map-get? incentive-configs { pool-id: pool-id })
    config (get total-incentives-allocated config)
    u0
  )
)

;; [ENHANCEMENT] Calculate incentive claim rate for a pool
(define-read-only (get-pool-claim-rate (pool-id uint))
  (match (map-get? incentive-configs { pool-id: pool-id })
    config (let (
      (allocated (get total-incentives-allocated config))
      (claimed (get total-incentives-claimed config))
    )
      (if (> allocated u0)
        (/ (* claimed u100) allocated)
        u0
      )
    )
    u0
  )
)

;; [ENHANCEMENT] Get comprehensive incentive summary for user
(define-read-only (get-user-incentive-summary (pool-id uint) (user principal))
  (let (
    (early-bird (map-get? user-incentives { pool-id: pool-id, user: user, incentive-type: "early-bird" }))
    (volume (map-get? user-incentives { pool-id: pool-id, user: user, incentive-type: "volume" }))
    (referral (map-get? user-incentives { pool-id: pool-id, user: user, incentive-type: "referral" }))
    (loyalty (map-get? user-incentives { pool-id: pool-id, user: user, incentive-type: "loyalty" }))
  )
    {
      has-early-bird: (is-some early-bird),
      has-volume: (is-some volume),
      has-referral: (is-some referral),
      has-loyalty: (is-some loyalty),
      total-pending: (get-user-total-pending-incentives pool-id user)
    }
  )
)

;; [ENHANCEMENT] Get detailed breakdown of incentives by type for pool
(define-read-only (get-pool-incentive-breakdown (pool-id uint))
  (match (map-get? pool-incentive-stats { pool-id: pool-id })
    stats {
      early-bird-total: (get total-early-bird-bonuses stats),
      volume-total: (get total-volume-bonuses stats),
      referral-total: (get total-referral-bonuses stats),
      loyalty-total: (get total-loyalty-bonuses stats),
      total-bettors-rewarded: (get total-bettors-rewarded stats),
      early-bird-count: (get early-bird-count stats)
    }
    {
      early-bird-total: u0,
      volume-total: u0,
      referral-total: u0,
      loyalty-total: u0,
      total-bettors-rewarded: u0,
      early-bird-count: u0
    }
  )
)

;; [ENHANCEMENT] Get referral tracking information
(define-read-only (get-referral-info (referrer principal) (referred-user principal) (pool-id uint))
  (map-get? referral-tracking { referrer: referrer, referred-user: referred-user, pool-id: pool-id })
)

;; [ENHANCEMENT] Count total successful referrals for a user
(define-read-only (get-user-referral-count (referrer principal))
  (let ((loyalty-history (map-get? user-loyalty-history { user: referrer })))
    (match loyalty-history
      history (get total-pools-participated history)
      u0
    )
  )
)

;; [ENHANCEMENT] Check if incentive has expired
(define-read-only (has-incentive-expired (pool-id uint) (user principal) (incentive-type (string-ascii 32)))
  (match (map-get? user-incentives { pool-id: pool-id, user: user, incentive-type: incentive-type })
    incentive (>= burn-block-height (get claim-deadline incentive))
    false
  )
)

;; [ENHANCEMENT] Get contract health metrics
(define-read-only (get-contract-health)
  {
    total-distributed: (var-get total-incentives-distributed),
    total-claimed: (var-get total-incentives-claimed),
    current-balance: (var-get contract-balance),
    active-pools: (var-get active-pools-with-incentives),
    available-for-claims: (var-get contract-balance)
  }
)

;; [ENHANCEMENT] Calculate incentive distribution efficiency
(define-read-only (get-incentive-efficiency)
  (let (
    (distributed (var-get total-incentives-distributed))
    (claimed (var-get total-incentives-claimed))
  )
    (if (> distributed u0)
      (/ (* claimed u100) distributed)
      u0
    )
  )
)

;; [ENHANCEMENT] Get pool participation metrics
(define-read-only (get-pool-participation-rate (pool-id uint))
  (match (map-get? pool-incentive-stats { pool-id: pool-id })
    stats {
      total-rewarded: (get total-bettors-rewarded stats),
      early-bird-count: (get early-bird-count stats),
      participation-score: (if (> (get total-bettors-rewarded stats) u0) u100 u0)
    }
    {
      total-rewarded: u0,
      early-bird-count: u0,
      participation-score: u0
    }
  )
)

;; [ENHANCEMENT] Get distribution of bonuses by type
(define-read-only (get-bonus-type-distribution (pool-id uint))
  (match (map-get? pool-incentive-stats { pool-id: pool-id })
    stats (let (
      (total (+ (+ (+ (get total-early-bird-bonuses stats) (get total-volume-bonuses stats)) (get total-referral-bonuses stats)) (get total-loyalty-bonuses stats)))
    )
      {
        early-bird-percent: (if (> total u0) (/ (* (get total-early-bird-bonuses stats) u100) total) u0),
        volume-percent: (if (> total u0) (/ (* (get total-volume-bonuses stats) u100) total) u0),
        referral-percent: (if (> total u0) (/ (* (get total-referral-bonuses stats) u100) total) u0),
        loyalty-percent: (if (> total u0) (/ (* (get total-loyalty-bonuses stats) u100) total) u0)
      }
    )
    {
      early-bird-percent: u0,
      volume-percent: u0,
      referral-percent: u0,
      loyalty-percent: u0
    }
  )
)

;; [ENHANCEMENT] Get user's complete incentive history
(define-read-only (get-user-incentive-history (user principal))
  (match (map-get? user-loyalty-history { user: user })
    history {
      pools-participated: (get total-pools-participated history),
      total-bets: (get total-bets-placed history),
      total-earned: (get total-incentives-earned history),
      total-claimed: (get total-incentives-claimed history),
      pending-amount: (- (get total-incentives-earned history) (get total-incentives-claimed history))
    }
    {
      pools-participated: u0,
      total-bets: u0,
      total-earned: u0,
      total-claimed: u0,
      pending-amount: u0
    }
  )
)

;; [ENHANCEMENT] Calculate return on investment for incentives
(define-read-only (calculate-incentive-roi (user-total-bet uint) (total-incentives-earned uint))
  (if (> user-total-bet u0)
    (/ (* total-incentives-earned u100) user-total-bet)
    u0
  )
)

;; [ENHANCEMENT] Get pool incentive utilization rate
(define-read-only (get-pool-incentive-utilization (pool-id uint))
  (match (map-get? incentive-configs { pool-id: pool-id })
    config (let (
      (allocated (get total-incentives-allocated config))
      (claimed (get total-incentives-claimed config))
    )
      {
        allocated: allocated,
        claimed: claimed,
        remaining: (if (>= allocated claimed) (- allocated claimed) u0),
        utilization-percent: (if (> allocated u0) (/ (* claimed u100) allocated) u0)
      }
    )
    {
      allocated: u0,
      claimed: u0,
      remaining: u0,
      utilization-percent: u0
    }
  )
)

;; [ENHANCEMENT] Validate bonus amount against cap
(define-read-only (is-bonus-within-cap (bonus-amount uint))
  (<= bonus-amount MAX-BONUS-PER-BET)
)

;; [ENHANCEMENT] Audit incentive configuration for compliance
(define-read-only (audit-pool-incentive-config (pool-id uint))
  (match (map-get? incentive-configs { pool-id: pool-id })
    config {
      pool-id: pool-id,
      all-incentives-enabled: (and (and (get early-bird-enabled config) (get volume-bonus-enabled config)) (and (get referral-enabled config) (get loyalty-enabled config))),
      total-allocated: (get total-incentives-allocated config),
      total-claimed: (get total-incentives-claimed config),
      config-created-at: (get created-at config)
    }
    {
      pool-id: pool-id,
      all-incentives-enabled: false,
      total-allocated: u0,
      total-claimed: u0,
      config-created-at: u0
    }
  )
)

;; [ENHANCEMENT] Generate system-wide incentive report
(define-read-only (get-system-incentive-report)
  {
    total-distributed: (var-get total-incentives-distributed),
    total-claimed: (var-get total-incentives-claimed),
    contract-balance: (var-get contract-balance),
    active-pools: (var-get active-pools-with-incentives),
    system-efficiency: (get-incentive-efficiency),
    contract-health: (get-contract-health),
    unique-users: (var-get total-unique-users),
    highest-bonus: (var-get highest-single-bonus),
    is-paused: (var-get contract-paused),
    emergency-mode: (var-get emergency-mode)
  }
)

;; [ENHANCEMENT] Get advanced user analytics
(define-read-only (get-user-analytics (user principal) (pool-id uint))
  (let (
    (bet-tracking (map-get? pool-bet-tracking { pool-id: pool-id, user: user }))
    (loyalty-history (map-get? user-loyalty-history { user: user }))
  )
    {
      bet-metrics: bet-tracking,
      loyalty-data: loyalty-history,
      incentive-summary: (get-user-incentive-summary pool-id user),
      roi: (match bet-tracking
        tracking (match loyalty-history
          history (calculate-incentive-roi (get total-bet-amount tracking) (get total-incentives-earned history))
          u0
        )
        u0
      )
    }
  )
)

;; [ENHANCEMENT] Get pool performance metrics
(define-read-only (get-pool-performance-metrics (pool-id uint))
  (let (
    (stats (map-get? pool-incentive-stats { pool-id: pool-id }))
    (config (map-get? incentive-configs { pool-id: pool-id }))
  )
    {
      incentive-stats: stats,
      configuration: config,
      breakdown: (get-pool-incentive-breakdown pool-id),
      utilization: (get-pool-incentive-utilization pool-id),
      participation: (get-pool-participation-rate pool-id)
    }
  )
)

;; [ENHANCEMENT] Calculate streak bonus eligibility
(define-read-only (calculate-streak-bonus-eligibility (pool-id uint) (user principal))
  (match (map-get? pool-bet-tracking { pool-id: pool-id, user: user })
    tracking (let (
      (consecutive-bets (get consecutive-bets tracking))
      (is-eligible (>= consecutive-bets STREAK-BONUS-THRESHOLD))
      (bonus-multiplier (if is-eligible (min (/ consecutive-bets u2) BONUS-MULTIPLIER-CAP) u1))
    )
      {
        is-eligible: is-eligible,
        consecutive-bets: consecutive-bets,
        bonus-multiplier: bonus-multiplier,
        threshold: STREAK-BONUS-THRESHOLD
      }
    )
    {
      is-eligible: false,
      consecutive-bets: u0,
      bonus-multiplier: u1,
      threshold: STREAK-BONUS-THRESHOLD
    }
  )
)

;; [ENHANCEMENT] Get contract status and health check
(define-read-only (get-contract-status)
  {
    is-operational: (and (not (var-get contract-paused)) (not (var-get emergency-mode))),
    is-paused: (var-get contract-paused),
    emergency-mode: (var-get emergency-mode),
    balance-sufficient: (> (var-get contract-balance) u0),
    active-pools: (var-get active-pools-with-incentives),
    total-users: (var-get total-unique-users)
  }
)

;; [ENHANCEMENT] Advanced incentive forecasting
(define-read-only (forecast-incentive-demand (pool-id uint) (projected-volume uint))
  (match (map-get? pool-incentive-stats { pool-id: pool-id })
    stats (let (
      (current-average (get average-bonus-amount stats))
      (estimated-users (/ projected-volume MINIMUM-BET-AMOUNT))
      (estimated-bonuses (* estimated-users current-average))
    )
      {
        projected-volume: projected-volume,
        estimated-users: estimated-users,
        estimated-total-bonuses: estimated-bonuses,
        current-average-bonus: current-average,
        funding-required: estimated-bonuses
      }
    )
    {
      projected-volume: projected-volume,
      estimated-users: u0,
      estimated-total-bonuses: u0,
      current-average-bonus: u0,
      funding-required: u0
    }
  )
)

;; [ENHANCEMENT] Dynamic bonus adjustment based on pool activity
(define-public (adjust-bonus-rates (pool-id uint) (early-bird-percent uint) (volume-percent uint) (referral-percent uint) (loyalty-percent uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (asserts! (<= early-bird-percent u20) ERR-INVALID-AMOUNT)
    (asserts! (<= volume-percent u10) ERR-INVALID-AMOUNT)
    (asserts! (<= referral-percent u10) ERR-INVALID-AMOUNT)
    (asserts! (<= loyalty-percent u10) ERR-INVALID-AMOUNT)
    
    (map-set pool-bonus-rates
      { pool-id: pool-id }
      {
        early-bird-percent: early-bird-percent,
        volume-percent: volume-percent,
        referral-percent: referral-percent,
        loyalty-percent: loyalty-percent
      }
    )
    (ok true)
  )
)

;; [ENHANCEMENT] Bulk incentive operations for efficiency
(define-public (bulk-initialize-pools (pool-ids (list 20 uint)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (ok (map initialize-single-pool pool-ids))
  )
)

;; Helper for bulk pool initialization
(define-private (initialize-single-pool (pool-id uint))
  (match (initialize-pool-incentives pool-id)
    success pool-id
    error u0
  )
)
;; [ENHANCEMENT] Advanced claim validation with anti-gaming measures
(define-private (validate-claim-legitimacy (pool-id uint) (user principal) (incentive-type (string-ascii 32)))
  (let (
    (bet-tracking (map-get? pool-bet-tracking { pool-id: pool-id, user: user }))
    (claims-count (match bet-tracking tracking (get claims-count tracking) u0))
  )
    (and
      (< claims-count MAX-CLAIMS-PER-USER)
      (> claims-count u0)  ;; Must have placed at least one bet
      (not (var-get emergency-mode))
    )
  )
)

;; [ENHANCEMENT] Incentive vesting schedule
(define-read-only (calculate-vesting-schedule (earned-at uint) (amount uint))
  (let (
    (blocks-since-earned (- burn-block-height earned-at))
    (vesting-period u1008) ;; 1 week vesting period
    (vested-percentage (if (>= blocks-since-earned vesting-period) u100 (/ (* blocks-since-earned u100) vesting-period)))
    (vested-amount (/ (* amount vested-percentage) u100))
  )
    {
      total-amount: amount,
      vested-amount: vested-amount,
      vesting-percentage: vested-percentage,
      fully-vested: (>= blocks-since-earned vesting-period)
    }
  )
)

;; [ENHANCEMENT] Gas optimization for batch operations
(define-private (optimize-batch-processing (operations-count uint))
  (let (
    (gas-per-operation u1000)
    (total-gas-estimate (* operations-count gas-per-operation))
    (max-gas-per-batch u50000)
    (recommended-batch-size (/ max-gas-per-batch gas-per-operation))
  )
    {
      operations-count: operations-count,
      estimated-gas: total-gas-estimate,
      recommended-batch-size: recommended-batch-size,
      requires-batching: (> operations-count recommended-batch-size)
    }
  )
)

;; [ENHANCEMENT] Comprehensive audit trail
(define-read-only (get-audit-trail (pool-id uint) (user principal))
  (let (
    (early-bird (map-get? user-incentives { pool-id: pool-id, user: user, incentive-type: "early-bird" }))
    (volume (map-get? user-incentives { pool-id: pool-id, user: user, incentive-type: "volume" }))
    (referral (map-get? user-incentives { pool-id: pool-id, user: user, incentive-type: "referral" }))
    (loyalty (map-get? user-incentives { pool-id: pool-id, user: user, incentive-type: "loyalty" }))
    (bet-tracking (map-get? pool-bet-tracking { pool-id: pool-id, user: user }))
    (leaderboard-entry (map-get? leaderboard-entries { pool-id: pool-id, user: user }))
  )
    {
      user: user,
      pool-id: pool-id,
      incentives: {
        early-bird: early-bird,
        volume: volume,
        referral: referral,
        loyalty: loyalty
      },
      betting-history: bet-tracking,
      leaderboard-data: leaderboard-entry,
      audit-timestamp: burn-block-height
    }
  )
)

;; [ENHANCEMENT] Time-based bonus multipliers
(define-read-only (calculate-time-based-multiplier (pool-created-at uint) (bet-placed-at uint))
  (let (
    (time-diff (- bet-placed-at pool-created-at))
    (hours-since-creation (/ time-diff u144)) ;; Assuming 144 blocks per day
  )
    (if (<= hours-since-creation u24)
      u3  ;; 3x multiplier for first 24 hours
      (if (<= hours-since-creation u168)
        u2  ;; 2x multiplier for first week
        u1  ;; 1x multiplier after first week
      )
    )
  )
)

;; [ENHANCEMENT] Incentive leaderboard functionality
(define-read-only (get-top-earners (pool-id uint) (limit uint))
  (let (
    (leaderboard (default-to { top-earners: (list), last-updated: u0 } (map-get? pool-leaderboards { pool-id: pool-id })))
    (top-earners (get top-earners leaderboard))
    (initial-acc { pool-id: pool-id, entries: (list) })
    (result (fold append-earner-entry top-earners initial-acc))
  )
    {
      pool-id: pool-id,
      earners: (get entries result),
      last-updated: (get last-updated leaderboard)
    }
  )
)

(define-private (append-earner-entry (user principal) (acc { pool-id: uint, entries: (list 10 { total-earned: uint, rank: (optional uint), user: principal }) }))
  (let (
    (pool-id (get pool-id acc))
    (entries (get entries acc))
    (entry (match (map-get? leaderboard-entries { pool-id: pool-id, user: user })
             e (merge e { user: user })
             { total-earned: u0, rank: none, user: user }))
  )
    { pool-id: pool-id, entries: (unwrap-panic (as-max-len? (append entries entry) u10)) }
  )
)

;; [NEW] Admin Controls for Leaderboard
(define-public (reset-pool-leaderboard (pool-id uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
    (map-delete pool-leaderboards { pool-id: pool-id })
    (ok true)
  )
)

;; [NEW] Batch retrieval for multiple pool leaderboards
(define-read-only (get-leaderboards-batch (pool-ids (list 20 uint)))
  (ok (map get-pool-leaderboard-summary pool-ids))
)

(define-private (get-pool-leaderboard-summary (pool-id uint))
  (match (map-get? pool-leaderboards { pool-id: pool-id })
    leaderboard { pool-id: pool-id, earner-count: (len (get top-earners leaderboard)), last-updated: (get last-updated leaderboard) }
    { pool-id: pool-id, earner-count: u0, last-updated: u0 }
  )
)

;; [NEW] Leaderboard Analytics
(define-read-only (get-leaderboard-analytics (pool-id uint))
  (let (
    (leaderboard (default-to { top-earners: (list), last-updated: u0 } (map-get? pool-leaderboards { pool-id: pool-id })))
  )
    {
      total-top-earners: (len (get top-earners leaderboard)),
      last-updated: (get last-updated leaderboard)
    }
  )
)

;; [NEW] Get User Tier Information
(define-read-only (get-user-tier (user principal))
  (default-to { tier: TIER-BRONZE, multiplier: u1, total-volume: u0 } (map-get? user-tiers { user: user }))
)

;; [NEW] Get User Reputation
(define-read-only (get-user-reputation (user principal))
  (default-to { score: u0, rank: "Newbie", last-updated: u0 } (map-get? user-reputation { user: user }))
)

;; [NEW] Get User Staking Status
(define-read-only (get-user-stake (user principal))
  (map-get? user-stakes { user: user })
)

;; [NEW] Get Global Leaderboard Entry
(define-read-only (get-global-leaderboard-entry (user principal))
  (default-to { total-earned: u0, last-earned-at: u0 } (map-get? global-leaderboard { user: user }))
)

;; [NEW] Get Oracle Reliability
(define-read-only (get-oracle-reliability (oracle principal))
  (default-to { successful-resolutions: u0, total-resolutions: u0, reliability-score: u0 } (map-get? oracle-reliability { oracle: oracle }))
)

;; [NEW] Get Referral Achievement Badges
(define-read-only (get-user-badges (user principal))
  (default-to { bronze-badge: false, silver-badge: false, gold-badge: false, platinum-badge: false } (map-get? referral-badges { user: user }))
)

;; [NEW] Award Referral Achievement Badge
(define-public (update-referral-badges (user principal))
  (let (
    (loyalty (default-to { total-pools-participated: u0, total-bets-placed: u0, total-incentives-earned: u0, total-incentives-claimed: u0 } (map-get? user-loyalty-history { user: user })))
    (referral-count (get total-pools-participated loyalty))
  )
    (map-set referral-badges { user: user } {
      bronze-badge: (>= referral-count u10),
      silver-badge: (>= referral-count u50),
      gold-badge: (>= referral-count u100),
      platinum-badge: (>= referral-count u500)
    })
    (ok true)
  )
)

;; [NEW] Get Pool Profitability Metrics
(define-read-only (get-pool-profitability (pool-id uint))
  (let (
    (stats (map-get? pool-incentive-stats { pool-id: pool-id }))
    (config (map-get? incentive-configs { pool-id: pool-id }))
  )
    {
      total-distributed: (match config c (get total-incentives-allocated c) u0),
      average-payout: (match stats s (get average-bonus-amount s) u0),
      peak-activity: (match stats s (get peak-activity-block s) u0),
      utilization-rate: (match config c (let ((allocated (get total-incentives-allocated c)) (claimed (get total-incentives-claimed c)))
        (if (> allocated u0) (/ (* claimed u100) allocated) u0)) u0)
    }
  )
)

;; [NEW] Historical ROI Tracking
(define-read-only (get-user-historical-roi (user principal))
  (let (
    (loyalty (map-get? user-loyalty-history { user: user }))
    (global-entry (map-get? global-leaderboard { user: user }))
  )
    {
      total-bet: (match loyalty l (get total-bets-placed l) u0),
      total-earned: (match global-entry g (get total-earned g) u0),
      roi-percentage: (match loyalty l (match global-entry g 
        (if (> (get total-bets-placed l) u0) 
          (/ (* (get total-earned g) u100) (get total-bets-placed l)) 
          u0) u0) u0)
    }
  )
)

;; [NEW] System Spend Forecasting
(define-read-only (forecast-weekly-spend (projected-users uint) (avg-bet-amount uint))
  (let (
    (estimated-total-bets (* projected-users u5))
    (estimated-volume (* estimated-total-bets avg-bet-amount))
    (estimated-bonuses (/ (* estimated-volume u5) u100))
  )
    {
      projected-users: projected-users,
      estimated-volume: estimated-volume,
      estimated-bonuses: estimated-bonuses,
      within-weekly-cap: (<= estimated-bonuses GLOBAL-WEEKLY-CAP),
      remaining-capacity: (if (>= GLOBAL-WEEKLY-CAP estimated-bonuses) (- GLOBAL-WEEKLY-CAP estimated-bonuses) u0)
    }
  )
)

;; [NEW] Get Global Spend Status
(define-read-only (get-global-spend-status)
  {
    daily-spend: (var-get global-daily-spend),
    weekly-spend: (var-get global-weekly-spend),
    daily-capacity: (- GLOBAL-DAILY-CAP (var-get global-daily-spend)),
    weekly-capacity: (- GLOBAL-WEEKLY-CAP (var-get global-weekly-spend)),
    last-reset: (var-get last-spend-reset-block)
  }
)

;; [NEW] Comprehensive User Dashboard
(define-read-only (get-user-dashboard (user principal))
  {
    tier: (get-user-tier user),
    reputation: (get-user-reputation user),
    stake: (get-user-stake user),
    global-rank: (get-global-leaderboard-entry user),
    badges: (get-user-badges user),
    roi: (get-user-historical-roi user)
  }
)
