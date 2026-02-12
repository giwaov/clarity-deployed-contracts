;; Aegis Staking Vault
;; Core staking contract for STX with lock periods
;; Rewards users with AGS tokens (5 tokens per day)
;; Supports 3-day, 7-day, and 30-day lock periods
;; 2% penalty on emergency withdrawals

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant CONTRACT-OWNER tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u3001))
(define-constant ERR-INSUFFICIENT-BALANCE (err u3002))
(define-constant ERR-INVALID-AMOUNT (err u3003))
(define-constant ERR-INVALID-LOCK-PERIOD (err u3004))
(define-constant ERR-NO-STAKE-FOUND (err u3005))
(define-constant ERR-STAKE-STILL-LOCKED (err u3006))
(define-constant ERR-ALREADY-STAKED (err u3007))
(define-constant ERR-CONTRACT-PAUSED (err u3008))
(define-constant ERR-ZERO-REWARDS (err u3009))
(define-constant ERR-MINT-FAILED (err u3010))

;; Staking parameters
(define-constant MIN-STAKE u10000)           ;; 0.01 STX in microSTX
(define-constant PENALTY-PERCENT u2)         ;; 2% emergency withdrawal penalty
(define-constant BLOCKS-PER-DAY u144)        ;; ~144 blocks per day on Stacks

;; Lock periods in blocks (approximately)
(define-constant LOCK-3-DAYS u432)           ;; 3 * 144 = 432 blocks
(define-constant LOCK-7-DAYS u1008)          ;; 7 * 144 = 1008 blocks
(define-constant LOCK-30-DAYS u4320)         ;; 30 * 144 = 4320 blocks

;; Reward rate: 5 AGS tokens per day (with 6 decimals)
(define-constant REWARD-RATE-PER-DAY u5000000)  ;; 5 * 10^6

;; Bonus multipliers (in basis points, 10000 = 1x)
(define-constant BONUS-3-DAYS u10000)        ;; 1.0x multiplier
(define-constant BONUS-7-DAYS u12000)        ;; 1.2x multiplier  
(define-constant BONUS-30-DAYS u15000)       ;; 1.5x multiplier

;; ============================================
;; DATA VARIABLES
;; ============================================

(define-data-var contract-paused bool false)
(define-data-var total-staked uint u0)
(define-data-var total-stakers uint u0)
(define-data-var total-rewards-distributed uint u0)
(define-data-var total-penalties-collected uint u0)
(define-data-var stake-counter uint u0)

;; ============================================
;; DATA MAPS
;; ============================================

;; Individual stake positions
(define-map stakes 
  { staker: principal, stake-id: uint }
  {
    amount: uint,
    start-block: uint,
    lock-period: uint,
    lock-period-type: uint,  ;; 3, 7, or 30
    last-claim-block: uint,
    is-active: bool
  }
)

;; Track user's stake IDs
(define-map user-stake-ids principal (list 20 uint))

;; Track user's total staked amount
(define-map user-total-staked principal uint)

;; ============================================
;; PRIVATE FUNCTIONS
;; ============================================

;; Get lock period in blocks based on type
(define-private (get-lock-blocks (lock-type uint))
  (if (is-eq lock-type u3)
    LOCK-3-DAYS
    (if (is-eq lock-type u7)
      LOCK-7-DAYS
      (if (is-eq lock-type u30)
        LOCK-30-DAYS
        u0
      )
    )
  )
)

;; Get bonus multiplier based on lock period
(define-private (get-bonus-multiplier (lock-type uint))
  (if (is-eq lock-type u3)
    BONUS-3-DAYS
    (if (is-eq lock-type u7)
      BONUS-7-DAYS
      (if (is-eq lock-type u30)
        BONUS-30-DAYS
        u10000
      )
    )
  )
)

;; Calculate penalty amount (2%)
(define-private (calculate-penalty (amount uint))
  (/ (* amount PENALTY-PERCENT) u100)
)

;; Calculate rewards for a stake
(define-private (calculate-rewards-internal (stake-amount uint) (blocks-elapsed uint) (lock-type uint))
  (let
    (
      (days-elapsed (/ blocks-elapsed BLOCKS-PER-DAY))
      (base-reward (* days-elapsed REWARD-RATE-PER-DAY))
      (multiplier (get-bonus-multiplier lock-type))
      ;; Scale reward by stake amount (per 1 STX staked)
      (scaled-reward (/ (* base-reward stake-amount) u1000000))
      ;; Apply bonus multiplier
      (final-reward (/ (* scaled-reward multiplier) u10000))
    )
    final-reward
  )
)

;; Add stake ID to user's list
(define-private (add-stake-id-to-user (user principal) (stake-id uint))
  (let
    (
      (current-ids (default-to (list) (map-get? user-stake-ids user)))
    )
    (map-set user-stake-ids user (unwrap! (as-max-len? (append current-ids stake-id) u20) false))
    true
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - STAKING
;; ============================================

;; Stake STX with selected lock period (3, 7, or 30 days)
(define-public (stake (amount uint) (lock-type uint))
  (let
    (
      (staker tx-sender)
      (lock-blocks (get-lock-blocks lock-type))
      (new-stake-id (+ (var-get stake-counter) u1))
    )
    ;; Validations
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (>= amount MIN-STAKE) ERR-INVALID-AMOUNT)
    (asserts! (> lock-blocks u0) ERR-INVALID-LOCK-PERIOD)
    (asserts! (>= (stx-get-balance staker) amount) ERR-INSUFFICIENT-BALANCE)
    
    ;; Transfer STX to vault
    (try! (stx-transfer? amount staker (as-contract tx-sender)))
    
    ;; Create stake position
    (map-set stakes
      { staker: staker, stake-id: new-stake-id }
      {
        amount: amount,
        start-block: block-height,
        lock-period: lock-blocks,
        lock-period-type: lock-type,
        last-claim-block: block-height,
        is-active: true
      }
    )
    
    ;; Update user tracking
    (add-stake-id-to-user staker new-stake-id)
    (map-set user-total-staked staker 
      (+ (default-to u0 (map-get? user-total-staked staker)) amount))
    
    ;; Update global stats
    (var-set stake-counter new-stake-id)
    (var-set total-staked (+ (var-get total-staked) amount))
    (var-set total-stakers (+ (var-get total-stakers) u1))
    
    (print { 
      event: "stake-created",
      staker: staker,
      stake-id: new-stake-id,
      amount: amount,
      lock-type: lock-type,
      lock-blocks: lock-blocks,
      unlock-block: (+ block-height lock-blocks)
    })
    
    (ok new-stake-id)
  )
)

;; Claim rewards without unstaking
(define-public (claim-rewards (stake-id uint))
  (let
    (
      (staker tx-sender)
      (stake-data (unwrap! (map-get? stakes { staker: staker, stake-id: stake-id }) ERR-NO-STAKE-FOUND))
      (stake-amount (get amount stake-data))
      (last-claim (get last-claim-block stake-data))
      (lock-type (get lock-period-type stake-data))
      (blocks-elapsed (- block-height last-claim))
      (rewards (calculate-rewards-internal stake-amount blocks-elapsed lock-type))
    )
    ;; Validations
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (get is-active stake-data) ERR-NO-STAKE-FOUND)
    (asserts! (> rewards u0) ERR-ZERO-REWARDS)
    
    ;; Mint reward tokens to staker
    (try! (contract-call? .aegis-token-v2 mint rewards staker))
    
    ;; Update last claim block
    (map-set stakes
      { staker: staker, stake-id: stake-id }
      (merge stake-data { last-claim-block: block-height })
    )
    
    ;; Update global stats
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) rewards))
    
    (print { 
      event: "rewards-claimed",
      staker: staker,
      stake-id: stake-id,
      rewards: rewards,
      blocks-elapsed: blocks-elapsed
    })
    
    (ok rewards)
  )
)

;; Normal withdrawal (after lock period ends)
(define-public (withdraw (stake-id uint))
  (let
    (
      (staker tx-sender)
      (stake-data (unwrap! (map-get? stakes { staker: staker, stake-id: stake-id }) ERR-NO-STAKE-FOUND))
      (stake-amount (get amount stake-data))
      (start-block (get start-block stake-data))
      (lock-period (get lock-period stake-data))
      (lock-type (get lock-period-type stake-data))
      (unlock-block (+ start-block lock-period))
      (last-claim (get last-claim-block stake-data))
      (blocks-elapsed (- block-height last-claim))
      (pending-rewards (calculate-rewards-internal stake-amount blocks-elapsed lock-type))
    )
    ;; Validations
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (get is-active stake-data) ERR-NO-STAKE-FOUND)
    (asserts! (>= block-height unlock-block) ERR-STAKE-STILL-LOCKED)
    
    ;; Claim any pending rewards first
    (if (> pending-rewards u0)
      (try! (contract-call? .aegis-token-v2 mint pending-rewards staker))
      true
    )
    
    ;; Return full staked amount
    (try! (as-contract (stx-transfer? stake-amount tx-sender staker)))
    
    ;; Deactivate stake
    (map-set stakes
      { staker: staker, stake-id: stake-id }
      (merge stake-data { is-active: false })
    )
    
    ;; Update user tracking
    (map-set user-total-staked staker 
      (- (default-to u0 (map-get? user-total-staked staker)) stake-amount))
    
    ;; Update global stats
    (var-set total-staked (- (var-get total-staked) stake-amount))
    (if (> pending-rewards u0)
      (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) pending-rewards))
      true
    )
    
    (print { 
      event: "withdrawal",
      staker: staker,
      stake-id: stake-id,
      amount: stake-amount,
      rewards: pending-rewards
    })
    
    (ok { amount: stake-amount, rewards: pending-rewards })
  )
)

;; Emergency withdrawal (with 2% penalty)
(define-public (emergency-withdraw (stake-id uint))
  (let
    (
      (staker tx-sender)
      (stake-data (unwrap! (map-get? stakes { staker: staker, stake-id: stake-id }) ERR-NO-STAKE-FOUND))
      (stake-amount (get amount stake-data))
      (penalty (calculate-penalty stake-amount))
      (return-amount (- stake-amount penalty))
    )
    ;; Validations
    (asserts! (not (var-get contract-paused)) ERR-CONTRACT-PAUSED)
    (asserts! (get is-active stake-data) ERR-NO-STAKE-FOUND)
    
    ;; Return 98% to staker
    (try! (as-contract (stx-transfer? return-amount tx-sender staker)))
    
    ;; Send 2% penalty to treasury (owner is same as deployer)
    (try! (as-contract (stx-transfer? penalty tx-sender CONTRACT-OWNER)))
    
    ;; Deactivate stake
    (map-set stakes
      { staker: staker, stake-id: stake-id }
      (merge stake-data { is-active: false })
    )
    
    ;; Update user tracking
    (map-set user-total-staked staker 
      (- (default-to u0 (map-get? user-total-staked staker)) stake-amount))
    
    ;; Update global stats
    (var-set total-staked (- (var-get total-staked) stake-amount))
    (var-set total-penalties-collected (+ (var-get total-penalties-collected) penalty))
    
    (print { 
      event: "emergency-withdrawal",
      staker: staker,
      stake-id: stake-id,
      original-amount: stake-amount,
      penalty: penalty,
      returned: return-amount
    })
    
    (ok { returned: return-amount, penalty: penalty })
  )
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

;; Get stake details
(define-read-only (get-stake (staker principal) (stake-id uint))
  (map-get? stakes { staker: staker, stake-id: stake-id })
)

;; Get user's stake IDs
(define-read-only (get-user-stake-ids (user principal))
  (default-to (list) (map-get? user-stake-ids user))
)

;; Get user's total staked amount
(define-read-only (get-user-total-staked (user principal))
  (default-to u0 (map-get? user-total-staked user))
)

;; Calculate pending rewards for a stake
(define-read-only (get-pending-rewards (staker principal) (stake-id uint))
  (match (map-get? stakes { staker: staker, stake-id: stake-id })
    stake-data
      (let
        (
          (stake-amount (get amount stake-data))
          (last-claim (get last-claim-block stake-data))
          (lock-type (get lock-period-type stake-data))
          (blocks-elapsed (- block-height last-claim))
        )
        (if (get is-active stake-data)
          (ok (calculate-rewards-internal stake-amount blocks-elapsed lock-type))
          (ok u0)
        )
      )
    (ok u0)
  )
)

;; Check if stake is unlocked
(define-read-only (is-stake-unlocked (staker principal) (stake-id uint))
  (match (map-get? stakes { staker: staker, stake-id: stake-id })
    stake-data
      (let
        (
          (unlock-block (+ (get start-block stake-data) (get lock-period stake-data)))
        )
        (>= block-height unlock-block)
      )
    false
  )
)

;; Get blocks until unlock
(define-read-only (get-blocks-until-unlock (staker principal) (stake-id uint))
  (match (map-get? stakes { staker: staker, stake-id: stake-id })
    stake-data
      (let
        (
          (unlock-block (+ (get start-block stake-data) (get lock-period stake-data)))
        )
        (if (>= block-height unlock-block)
          u0
          (- unlock-block block-height)
        )
      )
    u0
  )
)

;; Get vault statistics
(define-read-only (get-vault-stats)
  {
    total-staked: (var-get total-staked),
    total-stakers: (var-get total-stakers),
    total-rewards-distributed: (var-get total-rewards-distributed),
    total-penalties-collected: (var-get total-penalties-collected),
    vault-balance: (stx-get-balance (as-contract tx-sender)),
    is-paused: (var-get contract-paused)
  }
)

;; Get staking parameters
(define-read-only (get-staking-params)
  {
    min-stake: MIN-STAKE,
    penalty-percent: PENALTY-PERCENT,
    reward-rate-per-day: REWARD-RATE-PER-DAY,
    blocks-per-day: BLOCKS-PER-DAY,
    lock-3-days-blocks: LOCK-3-DAYS,
    lock-7-days-blocks: LOCK-7-DAYS,
    lock-30-days-blocks: LOCK-30-DAYS,
    bonus-3-days: BONUS-3-DAYS,
    bonus-7-days: BONUS-7-DAYS,
    bonus-30-days: BONUS-30-DAYS
  }
)

;; Get contract owner
(define-read-only (get-contract-owner)
  CONTRACT-OWNER
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

;; Pause contract
(define-public (pause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set contract-paused true)
    (print { event: "contract-paused" })
    (ok true)
  )
)

;; Unpause contract
(define-public (unpause)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set contract-paused false)
    (print { event: "contract-unpaused" })
    (ok true)
  )
)
