;; Staking Contract
;; Manages community staking pools, rewards, and slashing

(define-constant ERR-UNAUTHORIZED (err u6001))
(define-constant ERR-INSUFFICIENT-STAKE (err u6002))
(define-constant ERR-POOL-NOT-FOUND (err u6003))
(define-constant ERR-INVALID-AMOUNT (err u6004))
(define-constant ERR-LOCKED (err u6005))

(define-constant MIN-STAKE-AMOUNT u1000)
(define-constant REWARD-RATE u5) ;; 5% annual reward rate

;; Staking pool for each startup
(define-map staking-pools
    { startup-id: uint }
    {
        total-staked: uint,
        total-rewards: uint,
        reward-rate: uint,
        created-at: uint,
        last-reward-distribution: uint
    }
)

;; Individual stakes
(define-map stakes
    { staker: principal, startup-id: uint }
    {
        amount: uint,
        staked-at: uint,
        last-claim: uint,
        accumulated-rewards: uint
    }
)

;; Create staking pool for a startup
(define-public (create-staking-pool
    (startup-id uint)
    (reward-rate uint)
)
    (let
        (
            (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
        )
        (asserts! (is-none (map-get? staking-pools { startup-id: startup-id })) ERR-POOL-NOT-FOUND)
        (ok (map-set staking-pools
            { startup-id: startup-id }
            {
                total-staked: u0,
                total-rewards: u0,
                reward-rate: reward-rate,
                created-at: timestamp,
                last-reward-distribution: timestamp
            }
        ))
    )
)

;; Stake tokens to support a startup
(define-public (stake-tokens
    (startup-id uint)
    (amount uint)
)
    (let
        (
            (staker tx-sender)
            (pool (unwrap! (map-get? staking-pools { startup-id: startup-id }) ERR-POOL-NOT-FOUND))
            (existing-stake (map-get? stakes { staker: staker, startup-id: startup-id }))
            (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
        )
        (asserts! (>= amount MIN-STAKE-AMOUNT) ERR-INVALID-AMOUNT)
        (if (is-some existing-stake)
            (let
                (
                    (stake (unwrap! existing-stake ERR-UNAUTHORIZED))
                    (new-amount (+ (get amount stake) amount))
                )
                (begin
                    (map-set stakes
                        { staker: staker, startup-id: startup-id }
                        {
                            amount: new-amount,
                            staked-at: (get staked-at stake),
                            last-claim: timestamp,
                            accumulated-rewards: (get accumulated-rewards stake)
                        }
                    )
                    (map-set staking-pools
                        { startup-id: startup-id }
                        {
                            total-staked: (+ (get total-staked pool) amount),
                            total-rewards: (get total-rewards pool),
                            reward-rate: (get reward-rate pool),
                            created-at: (get created-at pool),
                            last-reward-distribution: (get last-reward-distribution pool)
                        }
                    )
                    (ok true)
                )
            )
            (begin
                (map-set stakes
                    { staker: staker, startup-id: startup-id }
                    {
                        amount: amount,
                        staked-at: timestamp,
                        last-claim: timestamp,
                        accumulated-rewards: u0
                    }
                )
                (map-set staking-pools
                    { startup-id: startup-id }
                    {
                        total-staked: (+ (get total-staked pool) amount),
                        total-rewards: (get total-rewards pool),
                        reward-rate: (get reward-rate pool),
                        created-at: (get created-at pool),
                        last-reward-distribution: (get last-reward-distribution pool)
                    }
                )
                (ok true)
            )
        )
    )
)

;; Unstake tokens
(define-public (unstake-tokens
    (startup-id uint)
    (amount uint)
)
    (let
        (
            (staker tx-sender)
            (stake (unwrap! (map-get? stakes { staker: staker, startup-id: startup-id }) ERR-INSUFFICIENT-STAKE))
            (pool (unwrap! (map-get? staking-pools { startup-id: startup-id }) ERR-POOL-NOT-FOUND))
            (current-amount (get amount stake))
        )
        (asserts! (>= current-amount amount) ERR-INSUFFICIENT-STAKE)
        (let
            (
                (new-amount (- current-amount amount))
            )
            (begin
                (if (is-eq new-amount u0)
                    (map-delete stakes { staker: staker, startup-id: startup-id })
                    (map-set stakes
                        { staker: staker, startup-id: startup-id }
                        {
                            amount: new-amount,
                            staked-at: (get staked-at stake),
                            last-claim: (get last-claim stake),
                            accumulated-rewards: (get accumulated-rewards stake)
                        }
                    )
                )
                (map-set staking-pools
                    { startup-id: startup-id }
                    {
                        total-staked: (- (get total-staked pool) amount),
                        total-rewards: (get total-rewards pool),
                        reward-rate: (get reward-rate pool),
                        created-at: (get created-at pool),
                        last-reward-distribution: (get last-reward-distribution pool)
                    }
                )
                (ok true)
            )
        )
    )
)

;; Calculate and claim rewards
(define-public (claim-rewards
    (startup-id uint)
)
    (let
        (
            (staker tx-sender)
            (stake (unwrap! (map-get? stakes { staker: staker, startup-id: startup-id }) ERR-INSUFFICIENT-STAKE))
            (pool (unwrap! (map-get? staking-pools { startup-id: startup-id }) ERR-POOL-NOT-FOUND))
            (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
            (time-elapsed (- timestamp (get last-claim stake)))
            (seconds-per-year u31536000)
        )
        (let
            (
                (rewards (/ (* (* (get amount stake) (get reward-rate pool)) time-elapsed) (* seconds-per-year u100)))
                (total-rewards (+ (get accumulated-rewards stake) rewards))
            )
            (begin
                (map-set stakes
                    { staker: staker, startup-id: startup-id }
                    {
                        amount: (get amount stake),
                        staked-at: (get staked-at stake),
                        last-claim: timestamp,
                        accumulated-rewards: total-rewards
                    }
                )
                (ok total-rewards)
            )
        )
    )
)

;; Distribute milestone rewards to stakers
(define-public (distribute-milestone-rewards
    (startup-id uint)
    (reward-amount uint)
)
    (let
        (
            (pool (unwrap! (map-get? staking-pools { startup-id: startup-id }) ERR-POOL-NOT-FOUND))
            (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
        )
        (ok (map-set staking-pools
            { startup-id: startup-id }
            {
                total-staked: (get total-staked pool),
                total-rewards: (+ (get total-rewards pool) reward-amount),
                reward-rate: (get reward-rate pool),
                created-at: (get created-at pool),
                last-reward-distribution: timestamp
            }
        ))
    )
)

;; Get staking pool info
(define-read-only (get-staking-pool (startup-id uint))
    (map-get? staking-pools { startup-id: startup-id })
)

;; Get stake info
(define-read-only (get-stake (staker principal) (startup-id uint))
    (map-get? stakes { staker: staker, startup-id: startup-id })
)

;; Calculate pending rewards
(define-read-only (calculate-pending-rewards
    (staker principal)
    (startup-id uint)
)
    (let
        (
            (stake (map-get? stakes { staker: staker, startup-id: startup-id }))
            (pool (map-get? staking-pools { startup-id: startup-id }))
        )
        (if (and (is-some stake) (is-some pool))
            (let
                (
                    (stake-data (unwrap! stake ERR-UNAUTHORIZED))
                    (pool-data (unwrap! pool ERR-UNAUTHORIZED))
                    (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
                    (time-elapsed (- timestamp (get last-claim stake-data)))
                    (seconds-per-year u31536000)
                )
                (ok (+ (get accumulated-rewards stake-data) (/ (* (* (get amount stake-data) (get reward-rate pool-data)) time-elapsed) (* seconds-per-year u100))))
            )
            (ok u0)
        )
    )
)

