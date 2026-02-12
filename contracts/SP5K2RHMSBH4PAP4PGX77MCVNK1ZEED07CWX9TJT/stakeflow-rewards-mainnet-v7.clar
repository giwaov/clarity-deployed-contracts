;; StakeFlow Rewards Contract V7
;; Calculate and distribute STF token rewards
;; MAINNET VERSION V7 - References staking-v7

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant REWARD-RATE u1000000) ;; 1 STF (with 6 decimals) per 10 blocks
(define-constant BLOCKS-PER-REWARD u10) ;; 1 STF every 10 blocks (~100 minutes)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-STAKED (err u101))
(define-constant ERR-NO-REWARDS (err u102))
(define-constant ERR-NOT-OWNER (err u103))

;; Authorized callers (unstake contract)
(define-map authorized-callers principal bool)

;; Data vars
(define-data-var reward-rate uint REWARD-RATE)
(define-data-var blocks-per-reward uint BLOCKS-PER-REWARD)
(define-data-var rewards-paused bool false)

;; Track total rewards distributed
(define-data-var total-rewards-distributed uint u0)

;; ---------------------------------------------------------
;; Authorization
;; ---------------------------------------------------------

(define-private (is-authorized-caller (caller principal))
  (default-to false (map-get? authorized-callers caller))
)

;; ---------------------------------------------------------
;; Reward Calculation Functions
;; ---------------------------------------------------------

(define-read-only (calculate-rewards (token-id uint))
  (let
    (
      ;; Reference staking v7 contract
      (stake-info (contract-call? 'SP5K2RHMSBH4PAP4PGX77MCVNK1ZEED07CWX9TJT.stakeflow-staking-mainnet-v7 get-stake-info token-id))
    )
    (match stake-info
      stake-data
        (let
          (
            (blocks-staked (- block-height (get last-claim stake-data)))
            (reward-periods (/ blocks-staked (var-get blocks-per-reward)))
            (rewards (* reward-periods (var-get reward-rate)))
          )
          rewards
        )
      u0
    )
  )
)

;; ---------------------------------------------------------
;; Claim Functions
;; ---------------------------------------------------------

(define-public (claim-rewards (token-id uint))
  (let
    (
      ;; Reference staking v7 contract
      (stake-info (unwrap! (contract-call? 'SP5K2RHMSBH4PAP4PGX77MCVNK1ZEED07CWX9TJT.stakeflow-staking-mainnet-v7 get-stake-info token-id) ERR-NOT-STAKED))
      (staker (get owner stake-info))
      (rewards (calculate-rewards token-id))
    )
    ;; Check not paused
    (asserts! (not (var-get rewards-paused)) ERR-NOT-AUTHORIZED)
    ;; Verify caller is the staker
    (asserts! (is-eq tx-sender staker) ERR-NOT-OWNER)
    ;; Check there are rewards to claim
    (asserts! (> rewards u0) ERR-NO-REWARDS)
    ;; Mint rewards to staker
    (try! (contract-call? 'SP5K2RHMSBH4PAP4PGX77MCVNK1ZEED07CWX9TJT.stakeflow-token-mainnet mint-for-staking rewards staker))
    ;; Update last claim
    (try! (contract-call? 'SP5K2RHMSBH4PAP4PGX77MCVNK1ZEED07CWX9TJT.stakeflow-staking-mainnet-v7 update-last-claim token-id))
    ;; Update total distributed
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) rewards))
    (ok rewards)
  )
)

;; ---------------------------------------------------------
;; Internal Functions (Called by unstake contract)
;; ---------------------------------------------------------

(define-public (claim-and-distribute (token-id uint) (recipient principal))
  (let
    (
      (rewards (calculate-rewards token-id))
    )
    ;; Only authorized contracts can call this
    (asserts! (is-authorized-caller contract-caller) ERR-NOT-AUTHORIZED)
    ;; If there are rewards, mint them
    (if (> rewards u0)
      (begin
        (try! (contract-call? 'SP5K2RHMSBH4PAP4PGX77MCVNK1ZEED07CWX9TJT.stakeflow-token-mainnet mint-for-staking rewards recipient))
        (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) rewards))
        (ok rewards)
      )
      (ok u0)
    )
  )
)

;; ---------------------------------------------------------
;; Read-only Functions
;; ---------------------------------------------------------

(define-read-only (get-reward-rate)
  (var-get reward-rate)
)

(define-read-only (get-blocks-per-reward)
  (var-get blocks-per-reward)
)

(define-read-only (get-total-rewards-distributed)
  (var-get total-rewards-distributed)
)

(define-read-only (is-rewards-paused)
  (var-get rewards-paused)
)

;; Estimate rewards per day (assuming ~144 blocks/day on Stacks)
(define-read-only (get-daily-reward-estimate)
  (let
    (
      (blocks-per-day u144)
      (periods-per-day (/ blocks-per-day (var-get blocks-per-reward)))
    )
    (* periods-per-day (var-get reward-rate))
  )
)

;; ---------------------------------------------------------
;; Admin Functions
;; ---------------------------------------------------------

(define-public (set-reward-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set reward-rate new-rate))
  )
)

(define-public (set-blocks-per-reward (new-blocks uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set blocks-per-reward new-blocks))
  )
)

(define-public (set-rewards-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set rewards-paused paused))
  )
)

(define-public (set-authorized-caller (caller principal) (authorized bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-callers caller authorized))
  )
)
