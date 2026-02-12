---
title: "Trait stakex-forge"
draft: true
---
```
;; Governance Staking - Stake Tokens for Voting Power (Clarity 4)
;; This contract allows users to stake governance tokens to increase voting power

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u2001))
(define-constant ERR-INSUFFICIENT-BALANCE (err u2002))
(define-constant ERR-NO-STAKE-FOUND (err u2003))
(define-constant ERR-STAKE-LOCKED (err u2004))
(define-constant ERR-INVALID-AMOUNT (err u2005))
(define-constant ERR-WITHDRAWAL-TOO-EARLY (err u2006))

;; Lock periods in seconds (Clarity 4)
(define-constant LOCK-PERIOD-SHORT u2592000)   ;; 30 days
(define-constant LOCK-PERIOD-MEDIUM u7776000)  ;; 90 days
(define-constant LOCK-PERIOD-LONG u15552000)   ;; 180 days

;; Multipliers in basis points (10000 = 1x)
(define-constant MULTIPLIER-SHORT u12000)      ;; 1.2x
(define-constant MULTIPLIER-MEDIUM u15000)     ;; 1.5x
(define-constant MULTIPLIER-LONG u20000)       ;; 2.0x

;; Data variables
(define-data-var total-staked uint u0)
(define-data-var total-stakers uint u0)
(define-data-var min-stake-amount uint u1000000) ;; 1 token with 6 decimals

;; Data maps
(define-map stakes
    { staker: principal }
    {
        amount: uint,
        lock-period: uint,
        staked-at: uint,                    ;; Clarity 4: Unix timestamp
        unlock-at: uint,                    ;; Clarity 4: Unix timestamp
        multiplier: uint,
        voting-power: uint,
        auto-compound: bool
    }
)

(define-map stake-history
    { staker: principal, index: uint }
    {
        action: (string-ascii 20),
        amount: uint,
        timestamp: uint,                    ;; Clarity 4: Unix timestamp
        lock-period: uint
    }
)

(define-map stake-count { staker: principal } uint)

(define-map delegated-stake
    { staker: principal }
    {
        delegate: principal,
        amount: uint,
        delegated-at: uint                  ;; Clarity 4: Unix timestamp
    }
)

;; Read-only functions
(define-read-only (get-stake (staker principal))
    (ok (map-get? stakes { staker: staker }))
)

(define-read-only (get-total-staked)
    (ok (var-get total-staked))
)

(define-read-only (get-total-stakers)
    (ok (var-get total-stakers))
)

(define-read-only (get-stake-history (staker principal) (index uint))
    (ok (map-get? stake-history { staker: staker, index: index }))
)

;; Private helper functions
(define-private (calculate-voting-power (amount uint) (multiplier uint))
    (/ (* amount multiplier) u10000)
)

;; Public functions
(define-public (stake (amount uint) (lock-period uint))
    (begin
        (asserts! (>= amount (var-get min-stake-amount)) ERR-INVALID-AMOUNT)
        (asserts! (or
            (is-eq lock-period LOCK-PERIOD-SHORT)
            (or
                (is-eq lock-period LOCK-PERIOD-MEDIUM)
                (is-eq lock-period LOCK-PERIOD-LONG)
            )
        ) ERR-INVALID-AMOUNT)

        (let
            (
                (multiplier (if (is-eq lock-period LOCK-PERIOD-SHORT)
                    MULTIPLIER-SHORT
                    (if (is-eq lock-period LOCK-PERIOD-MEDIUM)
                        MULTIPLIER-MEDIUM
                        MULTIPLIER-LONG
                    )
                ))
                (unlock-time (+ stacks-block-time lock-period))
                (voting-power (calculate-voting-power amount multiplier))
                (existing-stake (map-get? stakes { staker: tx-sender }))
                (history-index (default-to u0 (map-get? stake-count { staker: tx-sender })))
            )
            (match existing-stake
                stake-data
                    ;; Add to existing stake
                    (map-set stakes
                        { staker: tx-sender }
                        {
                            amount: (+ (get amount stake-data) amount),
                            lock-period: lock-period,
                            staked-at: stacks-block-time,
                            unlock-at: unlock-time,
                            multiplier: multiplier,
                            voting-power: (+ (get voting-power stake-data) voting-power),
                            auto-compound: (get auto-compound stake-data)
                        }
                    )
                ;; Create new stake
                (begin
                    (map-set stakes
                        { staker: tx-sender }
                        {
                            amount: amount,
                            lock-period: lock-period,
                            staked-at: stacks-block-time,
                            unlock-at: unlock-time,
                            multiplier: multiplier,
                            voting-power: voting-power,
                            auto-compound: false
                        }
                    )
                    (var-set total-stakers (+ (var-get total-stakers) u1))
                )
            )

            (var-set total-staked (+ (var-get total-staked) amount))

            ;; Record history
            (map-set stake-history
                { staker: tx-sender, index: history-index }
                {
                    action: "stake",
                    amount: amount,
                    timestamp: stacks-block-time,
                    lock-period: lock-period
                }
            )
            (map-set stake-count { staker: tx-sender } (+ history-index u1))

            (print {
                event: "tokens-staked",
                staker: tx-sender,
                amount: amount,
                lock-period: lock-period,
                voting-power: voting-power,
                unlock-at: unlock-time,
                timestamp: stacks-block-time
            })
            (ok voting-power)
        )
    )
)

(define-public (unstake (amount uint))
    (let
        (
            (stake-data (unwrap! (map-get? stakes { staker: tx-sender }) ERR-NO-STAKE-FOUND))
            (history-index (default-to u0 (map-get? stake-count { staker: tx-sender })))
        )
        (asserts! (>= stacks-block-time (get unlock-at stake-data)) ERR-STAKE-LOCKED)
        (asserts! (<= amount (get amount stake-data)) ERR-INSUFFICIENT-BALANCE)

        (let
            (
                (remaining-amount (- (get amount stake-data) amount))
                (voting-power-lost (/ (* (get voting-power stake-data) amount) (get amount stake-data)))
                (new-voting-power (- (get voting-power stake-data) voting-power-lost))
            )
            (if (is-eq remaining-amount u0)
                ;; Remove stake completely
                (begin
                    (map-delete stakes { staker: tx-sender })
                    (var-set total-stakers (- (var-get total-stakers) u1))
                )
                ;; Update stake
                (map-set stakes
                    { staker: tx-sender }
                    (merge stake-data {
                        amount: remaining-amount,
                        voting-power: new-voting-power
                    })
                )
            )

            (var-set total-staked (- (var-get total-staked) amount))

            ;; Record history
            (map-set stake-history
                { staker: tx-sender, index: history-index }
                {
                    action: "unstake",
                    amount: amount,
                    timestamp: stacks-block-time,
                    lock-period: u0
                }
            )
            (map-set stake-count { staker: tx-sender } (+ history-index u1))

            (print {
                event: "tokens-unstaked",
                staker: tx-sender,
                amount: amount,
                timestamp: stacks-block-time
            })
            (ok amount)
        )
    )
)

(define-public (extend-lock (new-lock-period uint))
    (let
        (
            (stake-data (unwrap! (map-get? stakes { staker: tx-sender }) ERR-NO-STAKE-FOUND))
        )
        (asserts! (or
            (is-eq new-lock-period LOCK-PERIOD-SHORT)
            (or
                (is-eq new-lock-period LOCK-PERIOD-MEDIUM)
                (is-eq new-lock-period LOCK-PERIOD-LONG)
            )
        ) ERR-INVALID-AMOUNT)
        (asserts! (> new-lock-period (get lock-period stake-data)) ERR-INVALID-AMOUNT)

        (let
            (
                (new-multiplier (if (is-eq new-lock-period LOCK-PERIOD-SHORT)
                    MULTIPLIER-SHORT
                    (if (is-eq new-lock-period LOCK-PERIOD-MEDIUM)
                        MULTIPLIER-MEDIUM
                        MULTIPLIER-LONG
                    )
                ))
                (new-unlock-time (+ stacks-block-time new-lock-period))
                (new-voting-power (calculate-voting-power (get amount stake-data) new-multiplier))
            )
            (map-set stakes
                { staker: tx-sender }
                (merge stake-data {
                    lock-period: new-lock-period,
                    unlock-at: new-unlock-time,
                    multiplier: new-multiplier,
                    voting-power: new-voting-power
                })
            )

            (print {
                event: "lock-extended",
                staker: tx-sender,
                new-lock-period: new-lock-period,
                new-voting-power: new-voting-power,
                timestamp: stacks-block-time
            })
            (ok true)
        )
    )
)

(define-public (toggle-auto-compound)
    (let
        (
            (stake-data (unwrap! (map-get? stakes { staker: tx-sender }) ERR-NO-STAKE-FOUND))
        )
        (map-set stakes
            { staker: tx-sender }
            (merge stake-data { auto-compound: (not (get auto-compound stake-data)) })
        )
        (ok true)
    )
)

(define-public (set-min-stake-amount (new-min uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (var-set min-stake-amount new-min)
        (ok true)
    )
)

(define-public (emergency-unstake)
    (let
        (
            (stake-data (unwrap! (map-get? stakes { staker: tx-sender }) ERR-NO-STAKE-FOUND))
            (penalty-amount (/ (get amount stake-data) u10))  ;; 10% penalty
            (return-amount (- (get amount stake-data) penalty-amount))
        )
        (map-delete stakes { staker: tx-sender })
        (var-set total-staked (- (var-get total-staked) (get amount stake-data)))
        (var-set total-stakers (- (var-get total-stakers) u1))

        (print {
            event: "emergency-unstake",
            staker: tx-sender,
            amount: return-amount,
            penalty: penalty-amount,
            timestamp: stacks-block-time
        })
        (ok return-amount)
    )
)

```
