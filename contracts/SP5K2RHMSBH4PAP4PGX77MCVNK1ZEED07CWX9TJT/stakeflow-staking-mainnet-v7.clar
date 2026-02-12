;; StakeFlow Staking Contract V7
;; Stake NFTs to earn STF token rewards
;; MAINNET VERSION V7 - References stakeflow-nft-mainnet-v6

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))
(define-constant ERR-ALREADY-STAKED (err u102))
(define-constant ERR-NOT-STAKED (err u103))
(define-constant ERR-TRANSFER-FAILED (err u104))

;; Authorized callers (rewards and unstake contracts)
(define-map authorized-callers principal bool)

;; Data structures
(define-map staked-nfts 
  { token-id: uint }
  { owner: principal, staked-at: uint, last-claim: uint }
)

;; Track total staked NFTs
(define-data-var total-staked uint u0)

;; Track staking status (for emergency pause)
(define-data-var staking-paused bool false)

;; ---------------------------------------------------------
;; Authorization
;; ---------------------------------------------------------

(define-private (is-authorized-caller (caller principal))
  (default-to false (map-get? authorized-callers caller))
)

;; ---------------------------------------------------------
;; Staking Functions
;; ---------------------------------------------------------

;; Stake an NFT
(define-public (stake-nft (token-id uint))
  (let
    (
      ;; Reference the deployed NFT v6 contract using full address
      (nft-owner (unwrap! (contract-call? 'SP5K2RHMSBH4PAP4PGX77MCVNK1ZEED07CWX9TJT.stakeflow-nft-mainnet-v6 get-owner token-id) ERR-NOT-TOKEN-OWNER))
    )
    ;; Check staking is not paused
    (asserts! (not (var-get staking-paused)) ERR-NOT-AUTHORIZED)
    ;; Verify caller owns the NFT
    (asserts! (is-eq (some tx-sender) nft-owner) ERR-NOT-TOKEN-OWNER)
    ;; Check not already staked
    (asserts! (is-none (map-get? staked-nfts { token-id: token-id })) ERR-ALREADY-STAKED)
    ;; Transfer NFT to this contract
    (try! (contract-call? 'SP5K2RHMSBH4PAP4PGX77MCVNK1ZEED07CWX9TJT.stakeflow-nft-mainnet-v6 transfer token-id tx-sender (as-contract tx-sender)))
    ;; Record stake info
    (map-set staked-nfts
      { token-id: token-id }
      { owner: tx-sender, staked-at: block-height, last-claim: block-height }
    )
    ;; Increment total staked
    (var-set total-staked (+ (var-get total-staked) u1))
    (ok true)
  )
)

;; ---------------------------------------------------------
;; Unstaking (via authorized contract)
;; ---------------------------------------------------------

;; Called by unstake contract to release NFT
(define-public (release-nft (token-id uint) (recipient principal))
  (let
    (
      (stake-info (unwrap! (map-get? staked-nfts { token-id: token-id }) ERR-NOT-STAKED))
    )
    ;; Only authorized contracts can call this
    (asserts! (is-authorized-caller contract-caller) ERR-NOT-AUTHORIZED)
    ;; Verify recipient is the original staker
    (asserts! (is-eq recipient (get owner stake-info)) ERR-NOT-AUTHORIZED)
    ;; Transfer NFT back to owner
    (try! (as-contract (contract-call? 'SP5K2RHMSBH4PAP4PGX77MCVNK1ZEED07CWX9TJT.stakeflow-nft-mainnet-v6 transfer token-id tx-sender recipient)))
    ;; Remove from staked map
    (map-delete staked-nfts { token-id: token-id })
    ;; Decrement total staked
    (var-set total-staked (- (var-get total-staked) u1))
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

(define-read-only (get-staker (token-id uint))
  (match (map-get? staked-nfts { token-id: token-id })
    stake-info (some (get owner stake-info))
    none
  )
)

(define-read-only (get-staked-at (token-id uint))
  (match (map-get? staked-nfts { token-id: token-id })
    stake-info (some (get staked-at stake-info))
    none
  )
)

(define-read-only (get-last-claim (token-id uint))
  (match (map-get? staked-nfts { token-id: token-id })
    stake-info (some (get last-claim stake-info))
    none
  )
)

(define-read-only (get-total-staked)
  (var-get total-staked)
)

(define-read-only (is-staking-paused)
  (var-get staking-paused)
)

;; ---------------------------------------------------------
;; Internal Functions (Called by rewards contract)
;; ---------------------------------------------------------

;; Update last claim time (called by rewards contract)
(define-public (update-last-claim (token-id uint))
  (let
    (
      (stake-info (unwrap! (map-get? staked-nfts { token-id: token-id }) ERR-NOT-STAKED))
    )
    ;; Only authorized contracts can update
    (asserts! (is-authorized-caller contract-caller) ERR-NOT-AUTHORIZED)
    ;; Update the last-claim
    (map-set staked-nfts
      { token-id: token-id }
      (merge stake-info { last-claim: block-height })
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

(define-public (set-authorized-caller (caller principal) (authorized bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-callers caller authorized))
  )
)
