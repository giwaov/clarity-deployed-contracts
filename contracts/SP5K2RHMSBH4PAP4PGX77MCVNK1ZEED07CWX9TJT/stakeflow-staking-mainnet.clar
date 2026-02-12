;; StakeFlow Staking Contract
;; Stake NFTs to earn STF rewards
;; MAINNET VERSION

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))
(define-constant ERR-ALREADY-STAKED (err u102))
(define-constant ERR-NOT-STAKED (err u103))
(define-constant ERR-TRANSFER-FAILED (err u104))

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

;; ---------------------------------------------------------
;; Staking Functions
;; ---------------------------------------------------------

(define-public (stake-nft (token-id uint))
  (let
    (
      (nft-owner (unwrap! (contract-call? .stakeflow-nft-mainnet get-owner token-id) ERR-NOT-TOKEN-OWNER))
    )
    ;; Check not paused
    (asserts! (not (var-get staking-paused)) ERR-NOT-AUTHORIZED)
    ;; Verify ownership
    (asserts! (is-eq (some tx-sender) nft-owner) ERR-NOT-TOKEN-OWNER)
    ;; Check not already staked
    (asserts! (is-none (map-get? staked-nfts { token-id: token-id })) ERR-ALREADY-STAKED)
    ;; Transfer NFT to this contract
    (try! (contract-call? .stakeflow-nft-mainnet transfer token-id tx-sender (as-contract tx-sender)))
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

;; ---------------------------------------------------------
;; Read-only Functions
;; ---------------------------------------------------------

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

;; ---------------------------------------------------------
;; Internal Functions (Called by other contracts)
;; ---------------------------------------------------------

(define-public (remove-stake (token-id uint))
  (let
    (
      (stake-data (unwrap! (map-get? staked-nfts { token-id: token-id }) ERR-NOT-STAKED))
      (original-owner (get owner stake-data))
    )
    ;; Only unstake contract can call this
    (asserts! (is-eq contract-caller .stakeflow-unstake-mainnet) ERR-NOT-AUTHORIZED)
    ;; Transfer NFT back to owner
    (try! (as-contract (contract-call? .stakeflow-nft-mainnet transfer token-id tx-sender original-owner)))
    ;; Remove stake record
    (map-delete staked-nfts { token-id: token-id })
    ;; Update staker info
    (map-set staker-info
      { staker: original-owner }
      { staked-count: (- (get-staked-count original-owner) u1) }
    )
    ;; Update total staked
    (var-set total-staked (- (var-get total-staked) u1))
    (ok original-owner)
  )
)

(define-public (update-last-claim (token-id uint))
  (let
    (
      (stake-data (unwrap! (map-get? staked-nfts { token-id: token-id }) ERR-NOT-STAKED))
    )
    ;; Only rewards contract can call this
    (asserts! (is-eq contract-caller .stakeflow-rewards-mainnet) ERR-NOT-AUTHORIZED)
    (map-set staked-nfts
      { token-id: token-id }
      (merge stake-data { last-claim: block-height })
    )
    (ok true)
  )
)

;; ---------------------------------------------------------
;; Admin Functions
;; ---------------------------------------------------------

(define-public (set-staking-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set staking-paused paused))
  )
)
