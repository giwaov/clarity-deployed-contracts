
;; nova-staking-rewards.clar
;; Users stake tokens to earn STX rewards (simulated).
;; CLARITY VERSION: 2

(use-trait nova-trait-fungible .nova-trait-fungible.nova-trait-fungible)

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-STAKE (err u101))

(define-map stakes
    principal
    {
        amount: uint,
        staked-at: uint
    }
)

(define-data-var reward-rate-per-block uint u10) ;; 10 microSTX per block per token unit (simplified)

(define-public (stake (amount uint) (token-trait <nova-trait-fungible>))
    (let (
        (sender tx-sender)
        (current-stake (default-to {amount: u0, staked-at: block-height} (map-get? stakes sender)))
    )
    ;; If already staked, claim rewards first (simplified for this example, we just update stake)
    (try! (contract-call? token-trait transfer amount sender (as-contract tx-sender) none))
    
    (map-set stakes sender {
        amount: (+ (get amount current-stake) amount),
        staked-at: block-height
    })
    (ok true))
)

(define-public (unstake (amount uint) (token-trait <nova-trait-fungible>))
    (let (
        (sender tx-sender)
        (stake-info (unwrap! (map-get? stakes sender) ERR-INSUFFICIENT-STAKE))
        (current-amount (get amount stake-info))
    )
    (asserts! (>= current-amount amount) ERR-INSUFFICIENT-STAKE)

    ;; Calculate rewards
    (let (
        (blocks-staked (- block-height (get staked-at stake-info)))
        (reward (* blocks-staked (var-get reward-rate-per-block) amount))
    )
        ;; Transfer principal back
        (try! (as-contract (contract-call? token-trait transfer amount tx-sender sender none)))
        ;; Transfer rewards (assuming contract has STX funding)
        (and (> reward u0) (try! (as-contract (stx-transfer? reward tx-sender sender))))
        
        (map-set stakes sender {
            amount: (- current-amount amount),
            staked-at: block-height
        })
        (ok reward)
    )
)
)

(define-public (fund-rewards (amount uint))
    (stx-transfer? amount tx-sender (as-contract tx-sender))
)
