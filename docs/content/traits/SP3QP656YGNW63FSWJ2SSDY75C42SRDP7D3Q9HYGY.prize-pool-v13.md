---
title: "Trait prize-pool-v13"
draft: true
---
```
;; Prize Pool Contract
;; Manages reward accumulation and distribution

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u400))
(define-constant err-insufficient-funds (err u401))
(define-constant err-invalid-amount (err u402))
(define-constant err-not-winner (err u403))

;; Reward distribution: 80% to winners, 20% protocol fee
(define-constant reward-percentage u8000)
(define-constant protocol-fee-percentage u2000)
(define-constant basis-points u10000)

;; Data structures
(define-data-var total-pool uint u0)
(define-data-var total-distributed uint u0)
(define-data-var protocol-fees-collected uint u0)

(define-map weekly-pools
  { week-start: uint }
  {
    total-collected: uint,
    total-distributed: uint,
    active-contracts: uint
  }
)

(define-map contract-pools
  { contract-id: uint }
  {
    total-deposited: uint,
    reward-pool: uint,
    protocol-fee: uint,
    distributed: uint
  }
)

;; Add funds to pool
(define-public (add-to-pool 
    (contract-id uint)
    (amount uint))
  (let
    (
      (reward-amount (/ (* amount reward-percentage) basis-points))
      (fee-amount (/ (* amount protocol-fee-percentage) basis-points))
      (pool (default-to 
        { total-deposited: u0, reward-pool: u0, protocol-fee: u0, distributed: u0 }
        (map-get? contract-pools { contract-id: contract-id })))
    )
    (asserts! (> amount u0) err-invalid-amount)
    
    ;; Update contract pool
    (map-set contract-pools
      { contract-id: contract-id }
      {
        total-deposited: (+ (get total-deposited pool) amount),
        reward-pool: (+ (get reward-pool pool) reward-amount),
        protocol-fee: (+ (get protocol-fee pool) fee-amount),
        distributed: (get distributed pool)
      }
    )
    
    ;; Update totals
    (var-set total-pool (+ (var-get total-pool) amount))
    (var-set protocol-fees-collected (+ (var-get protocol-fees-collected) fee-amount))
    
    (ok reward-amount)
  )
)

;; Distribute rewards to winner
(define-public (distribute-reward
    (contract-id uint)
    (recipient principal)
    (amount uint))
  (let
    (
      (pool (unwrap! (map-get? contract-pools { contract-id: contract-id }) err-not-winner))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (>= (get reward-pool pool) amount) err-insufficient-funds)
    
    ;; Transfer payout
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    
    ;; Update pool
    (map-set contract-pools
      { contract-id: contract-id }
      (merge pool {
        distributed: (+ (get distributed pool) amount)
      })
    )
    
    (var-set total-distributed (+ (var-get total-distributed) amount))
    
    (ok amount)
  )
)

;; Withdraw protocol fees
(define-public (withdraw-protocol-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (<= amount (var-get protocol-fees-collected)) err-insufficient-funds)
    
    (try! (as-contract (stx-transfer? amount tx-sender contract-owner)))
    (var-set protocol-fees-collected (- (var-get protocol-fees-collected) amount))
    
    (ok amount)
  )
)

;; Read-only functions
(define-read-only (get-pool-stats (contract-id uint))
  (ok (map-get? contract-pools { contract-id: contract-id }))
)

(define-read-only (get-total-pool)
  (ok (var-get total-pool))
)

(define-read-only (get-total-distributed)
  (ok (var-get total-distributed))
)

(define-read-only (get-protocol-fees)
  (ok (var-get protocol-fees-collected))
)

```
