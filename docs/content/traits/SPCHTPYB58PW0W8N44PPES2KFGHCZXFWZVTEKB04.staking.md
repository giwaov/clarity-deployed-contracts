---
title: "Trait staking"
draft: true
---
```
;; Simple Staking Contract
;; Stake tokens and earn rewards

(define-constant err-insufficient-balance (err u100))
(define-constant err-no-stake (err u101))
(define-constant err-not-owner (err u102))

(define-constant reward-rate u10) ;; 10% per reward cycle
(define-constant reward-cycle u2016) ;; ~2 weeks in blocks

(define-map stakes
    principal
    {
        amount: uint,
        start-block: uint,
        last-claim-block: uint
    }
)

(define-data-var total-staked uint u0)

;; Stake tokens
(define-public (stake (amount uint))
    (let
        (
            (existing-stake (map-get? stakes tx-sender))
        )
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        (match existing-stake
            stake-data
            ;; Update existing stake
            (begin
                (map-set stakes tx-sender {
                    amount: (+ (get amount stake-data) amount),
                    start-block: (get start-block stake-data),
                    last-claim-block: (get last-claim-block stake-data)
                })
            )
            ;; Create new stake
            (map-set stakes tx-sender {
                amount: amount,
                start-block: block-height,
                last-claim-block: block-height
            })
        )
        
        (var-set total-staked (+ (var-get total-staked) amount))
        (ok true)
    )
)

;; Unstake tokens
(define-public (unstake (amount uint))
    (let
        (
            (stake-data (unwrap! (map-get? stakes tx-sender) err-no-stake))
        )
        (asserts! (>= (get amount stake-data) amount) err-insufficient-balance)
        
        ;; Claim rewards first
        (try! (claim-rewards))
        
        ;; Transfer staked tokens back
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        
        (if (is-eq (get amount stake-data) amount)
            ;; Remove stake completely
            (map-delete stakes tx-sender)
            ;; Update stake amount
            (map-set stakes tx-sender (merge stake-data {
                amount: (- (get amount stake-data) amount)
            }))
        )
        
        (var-set total-staked (- (var-get total-staked) amount))
        (ok true)
    )
)

;; Claim rewards
(define-public (claim-rewards)
    (let
        (
            (stake-data (unwrap! (map-get? stakes tx-sender) err-no-stake))
            (rewards (calculate-rewards tx-sender))
        )
        (if (> rewards u0)
            (begin
                ;; In production, mint reward tokens or transfer from reserve
                (map-set stakes tx-sender (merge stake-data {
                    last-claim-block: block-height
                }))
                (print {event: "rewards-claimed", user: tx-sender, amount: rewards})
                (ok rewards)
            )
            (ok u0)
        )
    )
)

;; Calculate pending rewards
(define-read-only (calculate-rewards (staker principal))
    (match (map-get? stakes staker)
        stake-data
        (let
            (
                (blocks-passed (- block-height (get last-claim-block stake-data)))
                (cycles-completed (/ blocks-passed reward-cycle))
            )
            (/ (* (* (get amount stake-data) cycles-completed) reward-rate) u100)
        )
        u0
    )
)

;; Read-only functions
(define-read-only (get-stake (staker principal))
    (map-get? stakes staker)
)

(define-read-only (get-total-staked)
    (var-get total-staked)
)

(define-read-only (get-pending-rewards (staker principal))
    (calculate-rewards staker)
)

```
