;; Staking Rewards Contract
;; Provides TLX token rewards for long-term position holders
;; Rewards are paid in TLX tokens (minted on claim)
;; Uses Clarity 4 features

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-position-not-found (err u104))
(define-constant err-already-staked (err u105))
(define-constant err-not-staked (err u106))
(define-constant err-min-lock-not-met (err u107))
(define-constant err-rewards-not-available (err u108))
(define-constant err-cooldown-active (err u109))
(define-constant err-token-mint-failed (err u110))

;; TLX Token contract reference (must be set after deployment)
(define-data-var tlx-token-contract principal contract-owner)

;; Staking configuration
(define-data-var reward-rate-per-block uint u100) ;; Rewards per block per 1M STX staked
(define-data-var min-stake-amount uint u100000) ;; 0.1 STX minimum
(define-data-var min-lock-period uint u10080) ;; ~7 days in blocks
(define-data-var reward-pool-balance uint u0)
(define-data-var total-staked uint u0)
(define-data-var cooldown-period uint u1440) ;; ~1 day cooldown for unstaking

;; Reward tiers based on lock duration
(define-map reward-multipliers
  { tier: uint }
  { multiplier: uint, min-blocks: uint, name: (string-ascii 32) }
)

;; Staker data
(define-map stakers
  { address: principal }
  {
    staked-amount: uint,
    stake-start-block: uint,
    last-reward-block: uint,
    accumulated-rewards: uint,
    tier: uint,
    is-active: bool,
    cooldown-start: (optional uint)
  }
)

;; Staking history for analytics
(define-map staking-history
  { address: principal, index: uint }
  {
    action: (string-ascii 16),
    amount: uint,
    block-height: uint,
    rewards-claimed: uint
  }
)

(define-map user-history-count
  { address: principal }
  { count: uint }
)

;; Initialize reward tiers
(map-set reward-multipliers { tier: u1 } { multiplier: u100, min-blocks: u10080, name: "Bronze" })
(map-set reward-multipliers { tier: u2 } { multiplier: u150, min-blocks: u43200, name: "Silver" })
(map-set reward-multipliers { tier: u3 } { multiplier: u200, min-blocks: u129600, name: "Gold" })
(map-set reward-multipliers { tier: u4 } { multiplier: u300, min-blocks: u259200, name: "Platinum" })
(map-set reward-multipliers { tier: u5 } { multiplier: u500, min-blocks: u525600, name: "Diamond" })

;; Read-only functions

;; Get current reward rate
(define-read-only (get-reward-rate)
  (var-get reward-rate-per-block)
)

;; Get staker info
(define-read-only (get-staker-info (address principal))
  (map-get? stakers { address: address })
)

;; Get tier info
(define-read-only (get-tier-info (tier uint))
  (map-get? reward-multipliers { tier: tier })
)

;; Calculate pending rewards for a staker
(define-read-only (calculate-pending-rewards (address principal))
  (match (map-get? stakers { address: address })
    staker-data
      (if (get is-active staker-data)
        (let (
          (blocks-staked (- stacks-block-height (get last-reward-block staker-data)))
          (staked-amount (get staked-amount staker-data))
          (tier-data (unwrap! (map-get? reward-multipliers { tier: (get tier staker-data) }) u0))
          (base-reward (/ (* staked-amount (var-get reward-rate-per-block) blocks-staked) u1000000))
          (multiplied-reward (/ (* base-reward (get multiplier tier-data)) u100))
        )
          multiplied-reward
        )
        u0
      )
    u0
  )
)

;; Get total staked
(define-read-only (get-total-staked)
  (var-get total-staked)
)

;; Get reward pool balance
(define-read-only (get-reward-pool)
  (var-get reward-pool-balance)
)

;; Calculate APY based on current parameters
(define-read-only (calculate-apy (tier uint))
  (match (map-get? reward-multipliers { tier: tier })
    tier-data
      (let (
        (blocks-per-year u525600) ;; ~1 year in blocks (10 min blocks)
        (base-rate (var-get reward-rate-per-block))
        (yearly-rate (* base-rate blocks-per-year))
        (multiplied-rate (/ (* yearly-rate (get multiplier tier-data)) u100))
      )
        multiplied-rate
      )
    u0
  )
)

;; Determine tier based on lock duration
(define-read-only (determine-tier (blocks-locked uint))
  (if (>= blocks-locked u525600)
    u5
    (if (>= blocks-locked u259200)
      u4
      (if (>= blocks-locked u129600)
        u3
        (if (>= blocks-locked u43200)
          u2
          u1
        )
      )
    )
  )
)

;; Check if user is in cooldown
(define-read-only (is-in-cooldown (address principal))
  (match (map-get? stakers { address: address })
    staker-data
      (match (get cooldown-start staker-data)
        cooldown-block
          (< (- stacks-block-height cooldown-block) (var-get cooldown-period))
        false
      )
    false
  )
)

;; Get staking history for user
(define-read-only (get-staking-history (address principal) (index uint))
  (map-get? staking-history { address: address, index: index })
)

;; Public functions

;; Stake STX tokens
(define-public (stake (amount uint) (lock-duration uint))
  (let (
    (existing-stake (map-get? stakers { address: tx-sender }))
  )
    ;; Validate amount
    (asserts! (>= amount (var-get min-stake-amount)) err-invalid-amount)
    ;; Validate lock duration
    (asserts! (>= lock-duration (var-get min-lock-period)) err-min-lock-not-met)
    ;; Check if already staked
    (asserts! (is-none existing-stake) err-already-staked)
    
    ;; Transfer STX to contract
    (try! (stx-transfer? amount tx-sender current-contract))
    
    ;; Calculate tier based on lock duration
    (let (
      (tier (determine-tier lock-duration))
    )
      ;; Create staker record
      (map-set stakers
        { address: tx-sender }
        {
          staked-amount: amount,
          stake-start-block: stacks-block-height,
          last-reward-block: stacks-block-height,
          accumulated-rewards: u0,
          tier: tier,
          is-active: true,
          cooldown-start: none
        }
      )
      
      ;; Update total staked
      (var-set total-staked (+ (var-get total-staked) amount))
      
      ;; Record history
      (record-history tx-sender "stake" amount u0)
      
      (ok { staked: amount, tier: tier })
    )
  )
)

;; Add to existing stake
(define-public (add-stake (amount uint))
  (let (
    (staker-data (unwrap! (map-get? stakers { address: tx-sender }) err-not-staked))
  )
    ;; Validate amount
    (asserts! (> amount u0) err-invalid-amount)
    ;; Must be active staker
    (asserts! (get is-active staker-data) err-not-staked)
    
    ;; First claim any pending rewards
    (try! (claim-rewards))
    
    ;; Transfer additional STX
    (try! (stx-transfer? amount tx-sender current-contract))
    
    ;; Update staker record
    (map-set stakers
      { address: tx-sender }
      (merge staker-data {
        staked-amount: (+ (get staked-amount staker-data) amount)
      })
    )
    
    ;; Update total staked
    (var-set total-staked (+ (var-get total-staked) amount))
    
    ;; Record history
    (record-history tx-sender "add-stake" amount u0)
    
    (ok (+ (get staked-amount staker-data) amount))
  )
)

;; Claim accumulated rewards
(define-public (claim-rewards)
  (let (
    (staker-data (unwrap! (map-get? stakers { address: tx-sender }) err-not-staked))
    (pending (calculate-pending-rewards tx-sender))
  )
    ;; Must be active staker
    (asserts! (get is-active staker-data) err-not-staked)
    ;; Must have rewards to claim
    (asserts! (> pending u0) err-rewards-not-available)
    
    ;; Mint TLX tokens as reward (instead of STX transfer)
    (try! (contract-call? 'SP5K2RHMSBH4PAP4PGX77MCVNK1ZEED07CWX9TJT.timelock-token-v11-1 mint pending tx-sender))
    
    ;; Update staker record
    (map-set stakers
      { address: tx-sender }
      (merge staker-data {
        last-reward-block: stacks-block-height,
        accumulated-rewards: (+ (get accumulated-rewards staker-data) pending)
      })
    )
    
    ;; Update reward pool
    (var-set reward-pool-balance (- (var-get reward-pool-balance) pending))
    
    ;; Record history
    (record-history tx-sender "claim" u0 pending)
    
    (ok pending)
  )
)

;; Initiate unstake (starts cooldown)
(define-public (initiate-unstake)
  (let (
    (staker-data (unwrap! (map-get? stakers { address: tx-sender }) err-not-staked))
  )
    ;; Must be active staker
    (asserts! (get is-active staker-data) err-not-staked)
    ;; Must not already be in cooldown
    (asserts! (is-none (get cooldown-start staker-data)) err-cooldown-active)
    
    ;; Set cooldown start
    (map-set stakers
      { address: tx-sender }
      (merge staker-data {
        cooldown-start: (some stacks-block-height)
      })
    )
    
    (ok stacks-block-height)
  )
)

;; Complete unstake after cooldown
(define-public (complete-unstake)
  (let (
    (user tx-sender)
    (staker-data (unwrap! (map-get? stakers { address: tx-sender }) err-not-staked))
    (cooldown-start (unwrap! (get cooldown-start staker-data) err-cooldown-active))
  )
    ;; Must be active staker
    (asserts! (get is-active staker-data) err-not-staked)
    ;; Cooldown must have passed
    (asserts! (>= (- stacks-block-height cooldown-start) (var-get cooldown-period)) err-cooldown-active)
    
    ;; Claim any remaining rewards first
    (let (
      (pending (calculate-pending-rewards user))
      (staked-amount (get staked-amount staker-data))
    )
      ;; Transfer staked amount back (STX)
      (try! (as-contract? ((with-stx staked-amount)) (try! (stx-transfer? staked-amount tx-sender user))))
      
      ;; Mint any pending TLX rewards if available
      (and (> pending u0)
        (is-ok (contract-call? 'SP5K2RHMSBH4PAP4PGX77MCVNK1ZEED07CWX9TJT.timelock-token-v11-1 mint pending user)))
      
      ;; Update staker record
      (map-set stakers
        { address: user }
        (merge staker-data {
          staked-amount: u0,
          is-active: false,
          cooldown-start: none
        })
      )
      
      ;; Update total staked
      (var-set total-staked (- (var-get total-staked) staked-amount))
      
      ;; Record history
      (record-history user "unstake" staked-amount pending)
      
      (ok { unstaked: staked-amount, rewards: pending })
    )
  )
)

;; Cancel unstake cooldown
(define-public (cancel-unstake)
  (let (
    (staker-data (unwrap! (map-get? stakers { address: tx-sender }) err-not-staked))
  )
    ;; Must have active cooldown
    (asserts! (is-some (get cooldown-start staker-data)) err-cooldown-active)
    
    ;; Clear cooldown
    (map-set stakers
      { address: tx-sender }
      (merge staker-data {
        cooldown-start: none
      })
    )
    
    (ok true)
  )
)

;; Admin: Fund reward pool
(define-public (fund-reward-pool (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (> amount u0) err-invalid-amount)
    
    (try! (stx-transfer? amount tx-sender current-contract))
    (var-set reward-pool-balance (+ (var-get reward-pool-balance) amount))
    
    (ok (var-get reward-pool-balance))
  )
)

;; Admin: Update reward rate
(define-public (update-reward-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set reward-rate-per-block new-rate)
    (ok new-rate)
  )
)

;; Admin: Update minimum stake
(define-public (update-min-stake (new-min uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set min-stake-amount new-min)
    (ok new-min)
  )
)

;; Admin: Update cooldown period
(define-public (update-cooldown-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set cooldown-period new-period)
    (ok new-period)
  )
)

;; Admin: Set TLX token contract (call once after deployment)
(define-public (set-tlx-token-contract (token-contract principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set tlx-token-contract token-contract)
    (print { event: "tlx-token-set", contract: token-contract })
    (ok true)
  )
)

;; Read-only: Get TLX token contract
(define-read-only (get-tlx-token-contract)
  (var-get tlx-token-contract)
)

;; Private helper functions

;; Record staking history
(define-private (record-history (address principal) (action (string-ascii 16)) (amount uint) (rewards uint))
  (let (
    (current-count (default-to { count: u0 } (map-get? user-history-count { address: address })))
    (new-index (get count current-count))
  )
    (map-set staking-history
      { address: address, index: new-index }
      {
        action: action,
        amount: amount,
        block-height: stacks-block-height,
        rewards-claimed: rewards
      }
    )
    (map-set user-history-count
      { address: address }
      { count: (+ new-index u1) }
    )
    true
  )
)
