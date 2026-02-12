;; StakeFlow Unstake Contract
;; Unstake NFTs and claim rewards (0.001 STX fee)
;; MAINNET VERSION

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant TREASURY 'SP1ZYBVXD24AG7HNQ9PXB7TBCY2FD4YWT307FRKA3)
(define-constant UNSTAKE-FEE u1000) ;; 0.001 STX = 1,000 microSTX
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-STAKED (err u101))
(define-constant ERR-NOT-OWNER (err u102))
(define-constant ERR-TRANSFER-FAILED (err u103))
(define-constant ERR-INSUFFICIENT-FUNDS (err u104))

;; Data vars
(define-data-var unstake-fee uint UNSTAKE-FEE)
(define-data-var unstaking-paused bool false)
(define-data-var total-fees-collected uint u0)

;; ---------------------------------------------------------
;; Unstake Functions
;; ---------------------------------------------------------

(define-public (unstake-nft (token-id uint))
  (let
    (
      (stake-info (unwrap! (contract-call? .stakeflow-staking-mainnet get-stake-info token-id) ERR-NOT-STAKED))
      (staker (get owner stake-info))
    )
    ;; Check not paused
    (asserts! (not (var-get unstaking-paused)) ERR-NOT-AUTHORIZED)
    ;; Verify caller is the original staker
    (asserts! (is-eq tx-sender staker) ERR-NOT-OWNER)
    ;; Collect unstake fee
    (try! (stx-transfer? (var-get unstake-fee) tx-sender TREASURY))
    ;; Claim pending rewards
    (try! (contract-call? .stakeflow-rewards-mainnet claim-and-distribute token-id staker))
    ;; Remove stake and return NFT
    (try! (contract-call? .stakeflow-staking-mainnet remove-stake token-id))
    ;; Update fees collected
    (var-set total-fees-collected (+ (var-get total-fees-collected) (var-get unstake-fee)))
    (ok true)
  )
)

;; Emergency unstake without rewards (if rewards contract fails)
(define-public (emergency-unstake (token-id uint))
  (let
    (
      (stake-info (unwrap! (contract-call? .stakeflow-staking-mainnet get-stake-info token-id) ERR-NOT-STAKED))
      (staker (get owner stake-info))
    )
    ;; Verify caller is the original staker
    (asserts! (is-eq tx-sender staker) ERR-NOT-OWNER)
    ;; Collect unstake fee
    (try! (stx-transfer? (var-get unstake-fee) tx-sender TREASURY))
    ;; Remove stake and return NFT (skip rewards)
    (try! (contract-call? .stakeflow-staking-mainnet remove-stake token-id))
    ;; Update fees collected
    (var-set total-fees-collected (+ (var-get total-fees-collected) (var-get unstake-fee)))
    (ok true)
  )
)

;; ---------------------------------------------------------
;; Read-only Functions
;; ---------------------------------------------------------

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

;; ---------------------------------------------------------
;; Admin Functions
;; ---------------------------------------------------------

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
