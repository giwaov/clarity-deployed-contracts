;; Equity Token Contract
;; Manages equity tokenization, vesting schedules, and transfers

(define-constant ERR-UNAUTHORIZED (err u3001))
(define-constant ERR-INSUFFICIENT-BALANCE (err u3002))
(define-constant ERR-VESTING-ACTIVE (err u3003))
(define-constant ERR-INVALID-AMOUNT (err u3004))
(define-constant ERR-STARTUP-NOT-FOUND (err u3005))

(define-constant CONTRACT-OWNER tx-sender)

;; Token balances
(define-map balances
    { owner: principal }
    uint
)

;; Vesting schedules
(define-map vesting-schedules
    { recipient: principal, startup-id: uint }
    {
        total-amount: uint,
        vested-amount: uint,
        start-time: uint,
        cliff-duration: uint,
        vesting-duration: uint,
        release-interval: uint,
        last-release: uint
    }
)

;; Startup equity allocations
(define-map startup-equity
    { startup-id: uint }
    {
        total-supply: uint,
        reserved-amount: uint,
        distributed-amount: uint
    }
)

;; Initialize equity for a startup
(define-public (initialize-equity
    (startup-id uint)
    (total-supply uint)
    (reserved-amount uint)
)
    (let
        (
            (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
        )
        (asserts! (is-none (map-get? startup-equity { startup-id: startup-id })) ERR-STARTUP-NOT-FOUND)
        (asserts! (>= total-supply reserved-amount) ERR-INVALID-AMOUNT)
        (ok (map-set startup-equity
            { startup-id: startup-id }
            {
                total-supply: total-supply,
                reserved-amount: reserved-amount,
                distributed-amount: u0
            }
        ))
    )
)

;; Mint equity tokens to a recipient
(define-public (mint-equity
    (recipient principal)
    (startup-id uint)
    (amount uint)
)
    (let
        (
            (equity (unwrap! (map-get? startup-equity { startup-id: startup-id }) ERR-STARTUP-NOT-FOUND))
            (current-balance (default-to u0 (map-get? balances { owner: recipient })))
            (new-distributed (+ (get distributed-amount equity) amount))
        )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (<= new-distributed (get total-supply equity)) ERR-INVALID-AMOUNT)
        (begin
            (map-set balances { owner: recipient } (+ current-balance amount))
            (map-set startup-equity
                { startup-id: startup-id }
                {
                    total-supply: (get total-supply equity),
                    reserved-amount: (get reserved-amount equity),
                    distributed-amount: new-distributed
                }
            )
            (ok true)
        )
    )
)

;; Create vesting schedule
(define-public (create-vesting-schedule
    (recipient principal)
    (startup-id uint)
    (total-amount uint)
    (cliff-duration uint)
    (vesting-duration uint)
    (release-interval uint)
)
    (let
        (
            (timestamp (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
        )
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-UNAUTHORIZED)
        (asserts! (is-none (map-get? vesting-schedules { recipient: recipient, startup-id: startup-id })) ERR-VESTING-ACTIVE)
        (ok (map-set vesting-schedules
            { recipient: recipient, startup-id: startup-id }
            {
                total-amount: total-amount,
                vested-amount: u0,
                start-time: timestamp,
                cliff-duration: cliff-duration,
                vesting-duration: vesting-duration,
                release-interval: release-interval,
                last-release: timestamp
            }
        ))
    )
)

;; Release vested tokens
(define-public (release-vested-tokens
    (recipient principal)
    (startup-id uint)
)
    (let
        (
            (schedule (unwrap! (map-get? vesting-schedules { recipient: recipient, startup-id: startup-id }) ERR-VESTING-ACTIVE))
            (current-time (unwrap! (get-block-info? time u0) ERR-UNAUTHORIZED))
            (start-time (get start-time schedule))
            (cliff-end (+ start-time (get cliff-duration schedule)))
            (vesting-end (+ start-time (get vesting-duration schedule)))
        )
        (asserts! (>= current-time cliff-end) ERR-VESTING-ACTIVE)
        (let
            (
                (time-elapsed (- current-time start-time))
                (total-vested (if
                    (>= current-time vesting-end)
                    (get total-amount schedule)
                    (/ (* (get total-amount schedule) time-elapsed) (get vesting-duration schedule))
                ))
                (newly-vested (- total-vested (get vested-amount schedule)))
                (current-balance (default-to u0 (map-get? balances { owner: recipient })))
            )
            (asserts! (> newly-vested u0) ERR-INVALID-AMOUNT)
            (begin
                (map-set balances { owner: recipient } (+ current-balance newly-vested))
                (map-set vesting-schedules
                    { recipient: recipient, startup-id: startup-id }
                    {
                        total-amount: (get total-amount schedule),
                        vested-amount: total-vested,
                        start-time: start-time,
                        cliff-duration: (get cliff-duration schedule),
                        vesting-duration: (get vesting-duration schedule),
                        release-interval: (get release-interval schedule),
                        last-release: current-time
                    }
                )
                (ok newly-vested)
            )
        )
    )
)

;; Transfer equity tokens
(define-public (transfer-equity
    (recipient principal)
    (amount uint)
)
    (let
        (
            (sender tx-sender)
            (sender-balance (unwrap! (map-get? balances { owner: sender }) ERR-INSUFFICIENT-BALANCE))
            (recipient-balance (default-to u0 (map-get? balances { owner: recipient })))
        )
        (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
        (begin
            (map-set balances { owner: sender } (- sender-balance amount))
            (map-set balances { owner: recipient } (+ recipient-balance amount))
            (ok true)
        )
    )
)

;; Get balance
(define-read-only (get-balance (owner principal))
    (default-to u0 (map-get? balances { owner: owner }))
)

;; Get vesting schedule
(define-read-only (get-vesting-schedule (recipient principal) (startup-id uint))
    (map-get? vesting-schedules { recipient: recipient, startup-id: startup-id })
)

;; Get startup equity info
(define-read-only (get-startup-equity (startup-id uint))
    (map-get? startup-equity { startup-id: startup-id })
)

