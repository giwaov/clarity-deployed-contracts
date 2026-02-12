;; Title: SatsStaker - Secure Bitcoin Yield Generation Protocol
;;
;; Summary: A secure staking protocol for sBTC that generates yield for Bitcoin holders
;; on the Stacks Layer 2 platform, providing a non-custodial solution for earning 
;; passive income on Bitcoin assets.
;;
;; Description: 
;; This contract enables users to stake their sBTC (wrapped Bitcoin on Stacks) 
;; and earn proportional rewards based on time staked and amount. The protocol 
;; implements minimum staking periods, flexible reward rates, and secure
;; administration controls to ensure the long-term sustainability and security
;; of the protocol. SatsStaker bridges the traditional benefits of yield farming
;; with the security and sovereignty principles of Bitcoin.
;;

;; Error codes
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_ZERO_STAKE (err u101))
(define-constant ERR_NO_STAKE_FOUND (err u102))
(define-constant ERR_TOO_EARLY_TO_UNSTAKE (err u103))
(define-constant ERR_INVALID_REWARD_RATE (err u104))
(define-constant ERR_NOT_ENOUGH_REWARDS (err u105))

;; Data maps and variables
(define-map stakes
  { staker: principal }
  {
    amount: uint,
    staked-at: uint,
  }
)

(define-map rewards-claimed
  { staker: principal }
  { amount: uint }
)

(define-data-var reward-rate uint u5) ;; 0.5% in basis points (5/1000)
(define-data-var reward-pool uint u0)
(define-data-var min-stake-period uint u1440) ;; Minimum stake period in blocks (approx. 10 days on mainnet)
(define-data-var total-staked uint u0)

;; Administrative Functions

(define-data-var contract-owner principal tx-sender)

(define-read-only (get-contract-owner)
  (var-get contract-owner)
)

(define-public (set-contract-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    ;; Since this is a principal type, no additional validation needed but adding a check
    ;; to acknowledge the input was handled by validating the sender authorization
    (asserts! (not (is-eq new-owner (var-get contract-owner))) (ok true))
    (ok (var-set contract-owner new-owner))
  )
)

(define-public (set-reward-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (< new-rate u1000) ERR_INVALID_REWARD_RATE) ;; Cannot be more than 100%
    (ok (var-set reward-rate new-rate))
  )
)

(define-public (set-min-stake-period (new-period uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    ;; Add some basic validation for the new-period
    (asserts! (> new-period u0) ERR_INVALID_REWARD_RATE)
    (ok (var-set min-stake-period new-period))
  )
)

;; Add funds to the reward pool
(define-public (add-to-reward-pool (amount uint))
  (begin
    ;; Validate amount is greater than zero
    (asserts! (> amount u0) ERR_ZERO_STAKE)
    ;; Transfer sBTC to the contract
    (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      transfer amount tx-sender (as-contract tx-sender) none
    ))
    ;; Update reward pool - now the amount has been validated
    (var-set reward-pool (+ (var-get reward-pool) amount))
    (ok true)
  )
)

;; Staking Core Functions

(define-public (stake (amount uint))
  (begin
    (asserts! (> amount u0) ERR_ZERO_STAKE)
    ;; Transfer sBTC from user to the contract
    (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      transfer amount tx-sender (as-contract tx-sender) none
    ))
    ;; Update or create stake record
    (match (map-get? stakes { staker: tx-sender })
      prev-stake (map-set stakes { staker: tx-sender } {
        amount: (+ amount (get amount prev-stake)),
        staked-at: stacks-block-height,
      })
      (map-set stakes { staker: tx-sender } {
        amount: amount,
        staked-at: stacks-block-height,
      })
    )
    ;; Update total staked - amount has been validated above
    (var-set total-staked (+ (var-get total-staked) amount))
    (ok true)
  )
)

;; Calculate rewards for a staker
(define-read-only (calculate-rewards (staker principal))
  (match (map-get? stakes { staker: staker })
    stake-info (let (
        (stake-amount (get amount stake-info))
        (stake-duration (- stacks-block-height (get staked-at stake-info)))
        (reward-basis (/ (* stake-amount (var-get reward-rate)) u1000))
        (blocks-per-year u52560) ;; ~365 days on Stacks
        (time-factor (/ (* stake-duration u10000) blocks-per-year))
        (reward (* reward-basis (/ time-factor u10000)))
      )
      reward
    )
    u0
  )
)

;; Claim rewards without unstaking
(define-public (claim-rewards)
  (let (
      (stake-info (unwrap! (map-get? stakes { staker: tx-sender }) ERR_NO_STAKE_FOUND))
      (reward-amount (calculate-rewards tx-sender))
    )
    (asserts! (> reward-amount u0) ERR_NO_STAKE_FOUND)
    (asserts! (<= reward-amount (var-get reward-pool)) ERR_NOT_ENOUGH_REWARDS)
    ;; Update rewards pool - reward-amount has been validated above
    (var-set reward-pool (- (var-get reward-pool) reward-amount))
    ;; Update rewards claimed
    (match (map-get? rewards-claimed { staker: tx-sender })
      prev-claimed (map-set rewards-claimed { staker: tx-sender } { amount: (+ reward-amount (get amount prev-claimed)) })
      (map-set rewards-claimed { staker: tx-sender } { amount: reward-amount })
    )
    ;; Reset stake time to current block to restart reward calculation
    (map-set stakes { staker: tx-sender } {
      amount: (get amount stake-info),
      staked-at: stacks-block-height,
    })
    ;; Transfer rewards to the staker
    (as-contract (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      transfer reward-amount (as-contract tx-sender) tx-sender none
    )))
    (ok true)
  )
)

;; Unstake tokens and claim rewards
(define-public (unstake (amount uint))
  (let (
      (stake-info (unwrap! (map-get? stakes { staker: tx-sender }) ERR_NO_STAKE_FOUND))
      (staked-amount (get amount stake-info))
      (staked-at (get staked-at stake-info))
      (stake-duration (- stacks-block-height staked-at))
    )
    ;; Check conditions and validate amount
    (asserts! (> amount u0) ERR_ZERO_STAKE)
    (asserts! (>= staked-amount amount) ERR_NO_STAKE_FOUND)
    (asserts! (>= stake-duration (var-get min-stake-period))
      ERR_TOO_EARLY_TO_UNSTAKE
    )
    ;; Claim rewards first if available
    (try! (claim-rewards))
    ;; Update stake record
    (if (> staked-amount amount)
      (map-set stakes { staker: tx-sender } {
        amount: (- staked-amount amount),
        staked-at: stacks-block-height,
      })
      (map-delete stakes { staker: tx-sender })
    )
    ;; Update total staked - amount has been validated above
    (var-set total-staked (- (var-get total-staked) amount))
    ;; Transfer tokens back to the staker
    (as-contract (try! (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token
      transfer amount (as-contract tx-sender) tx-sender none
    )))
    (ok true)
  )
)

;; Read-only Interface Functions

(define-read-only (get-stake-info (staker principal))
  (map-get? stakes { staker: staker })
)

(define-read-only (get-rewards-claimed (staker principal))
  (map-get? rewards-claimed { staker: staker })
)

(define-read-only (get-reward-rate)
  (var-get reward-rate)
)

(define-read-only (get-min-stake-period)
  (var-get min-stake-period)
)

(define-read-only (get-reward-pool)
  (var-get reward-pool)
)

(define-read-only (get-total-staked)
  (var-get total-staked)
)

;; Calculate APY for the current reward rate
(define-read-only (get-current-apy)
  (let ((rate-basis (var-get reward-rate)))
    (* rate-basis u100)
    ;; convert basis points to percentage (e.g., 5 basis points = 0.5%)
  )
)
