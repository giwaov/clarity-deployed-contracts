;; StakeFlow Combined Contract v5.1
;; All-in-one: Stake, Rewards, Unstake
;; No cross-contract dependencies - only calls existing NFT and Token contracts

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant TREASURY 'SP1ZYBVXD24AG7HNQ9PXB7TBCY2FD4YWT307FRKA3)
(define-constant REWARD-RATE u1000000) ;; 1 STF (6 decimals) per reward period
(define-constant BLOCKS-PER-REWARD u10) ;; 1 STF every 10 blocks
(define-constant UNSTAKE-FEE u1000) ;; 0.001 STX = 1,000 microSTX

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))
(define-constant ERR-ALREADY-STAKED (err u102))
(define-constant ERR-NOT-STAKED (err u103))
(define-constant ERR-TRANSFER-FAILED (err u104))
(define-constant ERR-NO-REWARDS (err u105))
(define-constant ERR-INSUFFICIENT-FUNDS (err u106))

;; Data structures
(define-map staked-nfts
  { token-id: uint }
  {
    owner: principal,
    staked-at: uint,
    last-claim: uint
  }
)

(define-map staker-info
  { staker: principal }
  { staked-count: uint }
)

;; Data vars
(define-data-var total-staked uint u0)
(define-data-var staking-paused bool false)
(define-data-var reward-rate uint REWARD-RATE)
(define-data-var blocks-per-reward uint BLOCKS-PER-REWARD)
(define-data-var rewards-paused bool false)
(define-data-var total-rewards-distributed uint u0)
(define-data-var unstake-fee uint UNSTAKE-FEE)
(define-data-var unstaking-paused bool false)
(define-data-var total-fees-collected uint u0)

;; ==========================================================
;; STAKING FUNCTIONS
;; ==========================================================

(define-public (stake-nft (token-id uint))
  (let
    (
      (nft-owner (unwrap! (contract-call? 'SP5K2RHMSBH4PAP4PGX77MCVNK1ZEED07CWX9TJT.stakeflow-nft-mainnet-v2 get-owner token-id) ERR-NOT-TOKEN-OWNER))
    )
    ;; Check not paused
    (asserts! (not (var-get staking-paused)) ERR-NOT-AUTHORIZED)
    ;; Verify ownership
    (asserts! (is-eq (some tx-sender) nft-owner) ERR-NOT-TOKEN-OWNER)
    ;; Check not already staked
    (asserts! (is-none (map-get? staked-nfts { token-id: token-id })) ERR-ALREADY-STAKED)
    ;; Transfer NFT to this contract
    (try! (contract-call? 'SP5K2RHMSBH4PAP4PGX77MCVNK1ZEED07CWX9TJT.stakeflow-nft-mainnet-v2 transfer token-id tx-sender (as-contract tx-sender)))
    ;; Record stake
    (map-set staked-nfts
      { token-id: token-id }
      {
        owner: tx-sender,
        staked-at: block-height,
        last-claim: block-height
      }
    )
    ;; Update staker info
    (map-set staker-info
      { staker: tx-sender }
      { staked-count: (+ (get-staked-count tx-sender) u1) }
    )
    ;; Update total staked
    (var-set total-staked (+ (var-get total-staked) u1))
    (ok true)
  )
)

;; ==========================================================
;; REWARDS FUNCTIONS
;; ==========================================================

(define-read-only (calculate-rewards (token-id uint))
  (match (map-get? staked-nfts { token-id: token-id })
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

(define-public (claim-rewards (token-id uint))
  (let
    (
      (stake-data (unwrap! (map-get? staked-nfts { token-id: token-id }) ERR-NOT-STAKED))
      (staker (get owner stake-data))
      (rewards (calculate-rewards token-id))
    )
    ;; Check not paused
    (asserts! (not (var-get rewards-paused)) ERR-NOT-AUTHORIZED)
    ;; Verify caller is the staker
    (asserts! (is-eq tx-sender staker) ERR-NOT-TOKEN-OWNER)
    ;; Check there are rewards to claim
    (asserts! (> rewards u0) ERR-NO-REWARDS)
    ;; Mint rewards to staker
    (try! (contract-call? 'SP5K2RHMSBH4PAP4PGX77MCVNK1ZEED07CWX9TJT.stakeflow-token-mainnet mint-for-staking rewards staker))
    ;; Update last claim
    (map-set staked-nfts
      { token-id: token-id }
      (merge stake-data { last-claim: block-height })
    )
    ;; Update total distributed
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) rewards))
    (ok rewards)
  )
)

;; ==========================================================
;; UNSTAKE FUNCTIONS
;; ==========================================================

(define-public (unstake-nft (token-id uint))
  (let
    (
      (stake-data (unwrap! (map-get? staked-nfts { token-id: token-id }) ERR-NOT-STAKED))
      (staker (get owner stake-data))
      (rewards (calculate-rewards token-id))
    )
    ;; Check not paused
    (asserts! (not (var-get unstaking-paused)) ERR-NOT-AUTHORIZED)
    ;; Verify caller is the original staker
    (asserts! (is-eq tx-sender staker) ERR-NOT-TOKEN-OWNER)
    ;; Collect unstake fee
    (try! (stx-transfer? (var-get unstake-fee) tx-sender TREASURY))
    ;; Claim pending rewards if any
    (if (> rewards u0)
      (begin
        (try! (contract-call? 'SP5K2RHMSBH4PAP4PGX77MCVNK1ZEED07CWX9TJT.stakeflow-token-mainnet mint-for-staking rewards staker))
        (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) rewards))
      )
      true
    )
    ;; Transfer NFT back to owner
    (try! (as-contract (contract-call? 'SP5K2RHMSBH4PAP4PGX77MCVNK1ZEED07CWX9TJT.stakeflow-nft-mainnet-v2 transfer token-id tx-sender staker)))
    ;; Remove stake record
    (map-delete staked-nfts { token-id: token-id })
    ;; Update staker info
    (map-set staker-info
      { staker: staker }
      { staked-count: (- (get-staked-count staker) u1) }
    )
    ;; Update total staked
    (var-set total-staked (- (var-get total-staked) u1))
    ;; Update fees collected
    (var-set total-fees-collected (+ (var-get total-fees-collected) (var-get unstake-fee)))
    (ok true)
  )
)

;; Emergency unstake without rewards (if token mint fails)
(define-public (emergency-unstake (token-id uint))
  (let
    (
      (stake-data (unwrap! (map-get? staked-nfts { token-id: token-id }) ERR-NOT-STAKED))
      (staker (get owner stake-data))
    )
    ;; Verify caller is the original staker
    (asserts! (is-eq tx-sender staker) ERR-NOT-TOKEN-OWNER)
    ;; Collect unstake fee
    (try! (stx-transfer? (var-get unstake-fee) tx-sender TREASURY))
    ;; Transfer NFT back to owner
    (try! (as-contract (contract-call? 'SP5K2RHMSBH4PAP4PGX77MCVNK1ZEED07CWX9TJT.stakeflow-nft-mainnet-v2 transfer token-id tx-sender staker)))
    ;; Remove stake record
    (map-delete staked-nfts { token-id: token-id })
    ;; Update staker info
    (map-set staker-info
      { staker: staker }
      { staked-count: (- (get-staked-count staker) u1) }
    )
    ;; Update total staked
    (var-set total-staked (- (var-get total-staked) u1))
    ;; Update fees collected
    (var-set total-fees-collected (+ (var-get total-fees-collected) (var-get unstake-fee)))
    (ok true)
  )
)

;; ==========================================================
;; READ-ONLY FUNCTIONS
;; ==========================================================

(define-read-only (get-stake-info (token-id uint))
  (map-get? staked-nfts { token-id: token-id })
)

(define-read-only (is-staked (token-id uint))
  (is-some (map-get? staked-nfts { token-id: token-id }))
)

(define-read-only (get-staked-count (staker principal))
  (default-to u0 (get staked-count (map-get? staker-info { staker: staker })))
)

(define-read-only (get-total-staked)
  (var-get total-staked)
)

(define-read-only (get-blocks-staked (token-id uint))
  (match (map-get? staked-nfts { token-id: token-id })
    stake-data (- block-height (get staked-at stake-data))
    u0
  )
)

(define-read-only (get-staker (token-id uint))
  (match (map-get? staked-nfts { token-id: token-id })
    stake-data (some (get owner stake-data))
    none
  )
)

(define-read-only (is-staking-paused)
  (var-get staking-paused)
)

(define-read-only (get-reward-rate)
  (var-get reward-rate)
)

(define-read-only (get-blocks-per-reward)
  (var-get blocks-per-reward)
)

(define-read-only (is-rewards-paused)
  (var-get rewards-paused)
)

(define-read-only (get-total-rewards-distributed)
  (var-get total-rewards-distributed)
)

(define-read-only (get-unstake-fee)
  (var-get unstake-fee)
)

(define-read-only (get-total-fees-collected)
  (var-get total-fees-collected)
)

(define-read-only (is-unstaking-paused)
  (var-get unstaking-paused)
)

(define-read-only (get-treasury)
  TREASURY
)

;; ==========================================================
;; ADMIN FUNCTIONS
;; ==========================================================

(define-public (set-staking-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set staking-paused paused))
  )
)

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

(define-public (set-unstake-fee (new-fee uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set unstake-fee new-fee))
  )
)

(define-public (set-unstaking-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set unstaking-paused paused))
  )
)
