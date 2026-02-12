---
title: "Trait NFTUniverse"
draft: true
---
```
;; title: NFTUniverse
;; version:
;; summary:
;; description:

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-OWNER (err u100))
(define-constant ERR-NOT-STAKED (err u101))
(define-constant ERR-ALREADY-STAKED (err u102))
(define-constant ERR-INSUFFICIENT-FUNDS (err u103))
(define-constant ERR-INVALID-NFT (err u104))
(define-constant ERR-COOLDOWN-PERIOD (err u105))

;; data vars
(define-data-var total-staked uint u0)
(define-data-var reward-rate uint u100)
(define-data-var pool-balance uint u0)
(define-data-var contract-enabled bool true)

;; data maps
(define-map staked-nfts 
  { token-id: uint, nft-contract: principal }
  { 
    owner: principal, 
    stake-block: uint,
    last-claim-block: uint
  }
)

(define-map user-stakes 
  principal 
  { 
    nft-count: uint,
    total-rewards: uint
  }
)

;; public functions

(define-public (stake-nft (nft-contract principal) (token-id uint))
  (let (
    (stake-key { token-id: token-id, nft-contract: nft-contract })
    (current-stakes (default-to { nft-count: u0, total-rewards: u0 } (map-get? user-stakes tx-sender)))
  )
    (asserts! (var-get contract-enabled) (err u999))
    (asserts! (is-none (map-get? staked-nfts stake-key)) ERR-ALREADY-STAKED)
    
    (map-set staked-nfts stake-key {
      owner: tx-sender,
      stake-block: stacks-block-height,
      last-claim-block: stacks-block-height
    })
    
    (map-set user-stakes tx-sender {
      nft-count: (+ (get nft-count current-stakes) u1),
      total-rewards: (get total-rewards current-stakes)
    })
    
    (var-set total-staked (+ (var-get total-staked) u1))
    (ok true)
  )
)


(define-public (set-reward-rate (new-rate uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-OWNER)
    (var-set reward-rate new-rate)
    (ok true)
  )
)

(define-public (toggle-contract (enabled bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-OWNER)
    (var-set contract-enabled enabled)
    (ok true)
  )
)

;; read only functions

(define-read-only (get-stake-info (nft-contract principal) (token-id uint))
  (map-get? staked-nfts { token-id: token-id, nft-contract: nft-contract })
)

(define-read-only (get-user-stakes (user principal))
  (map-get? user-stakes user)
)

(define-read-only (calculate-rewards (stake-key { token-id: uint, nft-contract: principal }))
  (match (map-get? staked-nfts stake-key)
    stake-info
    (let (
      (blocks-staked (- stacks-block-height (get last-claim-block stake-info)))
      (reward-per-block (var-get reward-rate))
    )
      (* blocks-staked reward-per-block)
    )
    u0
  )
)

(define-read-only (get-pending-rewards (nft-contract principal) (token-id uint))
  (calculate-rewards { token-id: token-id, nft-contract: nft-contract })
)

(define-read-only (get-pool-stats)
  {
    total-staked: (var-get total-staked),
    pool-balance: (var-get pool-balance),
    reward-rate: (var-get reward-rate),
    contract-enabled: (var-get contract-enabled)
  }
)


```
