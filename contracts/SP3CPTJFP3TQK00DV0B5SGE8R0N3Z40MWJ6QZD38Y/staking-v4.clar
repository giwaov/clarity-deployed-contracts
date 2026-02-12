;; staking-v4.clar
;; Staking contract using stacks-block-time for rewards calculation

(define-map stakes principal { amount: uint, staked-at: uint })
(define-constant REWARD_RATE u1) ;; 1 token per second conceptual

(define-public (stake (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set stakes tx-sender { amount: amount, staked-at: block-height })
        (ok true)
    )
)

(define-public (unstake)
    (let
        (
            (entry (unwrap! (map-get? stakes tx-sender) (err u100)))
            (amount (get amount entry))
            (staked-at (get staked-at entry))
            (current-time block-height)
            (time-diff (- current-time staked-at))
            (reward (* amount time-diff)) ;; Simplified linear reward
        )
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        ;; Normally we would mint a reward token here, but we'll just log it or simulate it
        (print { msg: "Reward calculated", reward: reward })
        (map-delete stakes tx-sender)
        (ok reward)
    )
)
