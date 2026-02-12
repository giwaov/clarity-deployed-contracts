;; Reputation Tracker Contract
;; Manages user reputation scores for both workers and task creators

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-RATING (err u101))
(define-constant ERR-USER-NOT-FOUND (err u102))
(define-constant ERR-INVALID-CALLER (err u103))

;; Rating bounds
(define-constant MIN-RATING u1)
(define-constant MAX-RATING u5)

;; Reputation calculation weights
(define-constant COMPLETED-TASK-WEIGHT u100)
(define-constant RATING-WEIGHT u200)
(define-constant DISPUTE-LOST-PENALTY u300)
(define-constant DISPUTE-WON-BONUS u50)

;; Data Maps
(define-map user-reputation
    { user: principal }
    {
        total-tasks-completed: uint,
        total-tasks-created: uint,
        total-ratings: uint,
        sum-ratings: uint,
        disputes-opened: uint,
        disputes-won: uint,
        disputes-lost: uint,
        total-earned: uint,
        total-spent: uint
    }
)

;; Authorization map for allowed contract callers
(define-map authorized-contracts principal bool)

;; Initialize authorization
(map-set authorized-contracts CONTRACT-OWNER true)

;; Read-only functions

(define-read-only (get-reputation (user principal))
    (let (
        (user-stats (default-to 
            {
                total-tasks-completed: u0,
                total-tasks-created: u0,
                total-ratings: u0,
                sum-ratings: u0,
                disputes-opened: u0,
                disputes-won: u0,
                disputes-lost: u0,
                total-earned: u0,
                total-spent: u0
            }
            (map-get? user-reputation { user: user })
        ))
    )
    (ok (calculate-reputation-score user-stats)))
)

(define-read-only (get-user-stats (user principal))
    (ok (default-to 
        {
            total-tasks-completed: u0,
            total-tasks-created: u0,
            total-ratings: u0,
            sum-ratings: u0,
            disputes-opened: u0,
            disputes-won: u0,
            disputes-lost: u0,
            total-earned: u0,
            total-spent: u0
        }
        (map-get? user-reputation { user: user })
    ))
)

(define-read-only (get-average-rating (user principal))
    (let (
        (user-stats (unwrap! (map-get? user-reputation { user: user }) (ok u0)))
        (total-ratings (get total-ratings user-stats))
        (sum-ratings (get sum-ratings user-stats))
    )
    (if (> total-ratings u0)
        (ok (/ (* sum-ratings u100) total-ratings))
        (ok u0)
    ))
)

(define-read-only (get-completion-rate (user principal))
    (let (
        (user-stats (unwrap! (map-get? user-reputation { user: user }) (ok u0)))
        (completed (get total-tasks-completed user-stats))
        (created (get total-tasks-created user-stats))
        (total (+ completed created))
    )
    (if (> total u0)
        (ok (/ (* completed u10000) total))
        (ok u0)
    ))
)

(define-read-only (is-authorized-contract (contract principal))
    (ok (default-to false (map-get? authorized-contracts contract)))
)

;; Private functions

(define-private (calculate-reputation-score (stats (tuple 
    (total-tasks-completed uint)
    (total-tasks-created uint)
    (total-ratings uint)
    (sum-ratings uint)
    (disputes-opened uint)
    (disputes-won uint)
    (disputes-lost uint)
    (total-earned uint)
    (total-spent uint)
)))
    (let (
        (completed-score (* (get total-tasks-completed stats) COMPLETED-TASK-WEIGHT))
        (avg-rating-score (if (> (get total-ratings stats) u0)
            (/ (* (get sum-ratings stats) RATING-WEIGHT) (get total-ratings stats))
            u0
        ))
        (dispute-penalty (* (get disputes-lost stats) DISPUTE-LOST-PENALTY))
        (dispute-bonus (* (get disputes-won stats) DISPUTE-WON-BONUS))
        (raw-score (+ (+ completed-score avg-rating-score) dispute-bonus))
    )
    (if (> raw-score dispute-penalty)
        (- raw-score dispute-penalty)
        u0
    ))
)

(define-private (get-or-create-user-stats (user principal))
    (default-to 
        {
            total-tasks-completed: u0,
            total-tasks-created: u0,
            total-ratings: u0,
            sum-ratings: u0,
            disputes-opened: u0,
            disputes-won: u0,
            disputes-lost: u0,
            total-earned: u0,
            total-spent: u0
        }
        (map-get? user-reputation { user: user })
    )
)

;; Public functions

(define-public (authorize-contract (contract principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (ok (map-set authorized-contracts contract true))
    )
)

(define-public (revoke-contract (contract principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (ok (map-delete authorized-contracts contract))
    )
)

(define-public (record-completion (user principal) (is-worker bool) (rating uint))
    (begin
        ;; Only authorized contracts can call this
        (asserts! (default-to false (map-get? authorized-contracts contract-caller)) ERR-NOT-AUTHORIZED)
        
        ;; Validate rating
        (asserts! (and (>= rating MIN-RATING) (<= rating MAX-RATING)) ERR-INVALID-RATING)
        
        (let (
            (current-stats (get-or-create-user-stats user))
            (new-stats (if is-worker
                (merge current-stats {
                    total-tasks-completed: (+ (get total-tasks-completed current-stats) u1),
                    total-ratings: (+ (get total-ratings current-stats) u1),
                    sum-ratings: (+ (get sum-ratings current-stats) rating)
                })
                (merge current-stats {
                    total-tasks-created: (+ (get total-tasks-created current-stats) u1),
                    total-ratings: (+ (get total-ratings current-stats) u1),
                    sum-ratings: (+ (get sum-ratings current-stats) rating)
                })
            ))
        )
        (ok (map-set user-reputation { user: user } new-stats)))
    )
)

(define-public (record-task-created (creator principal) (amount uint))
    (begin
        ;; Only authorized contracts can call this
        (asserts! (default-to false (map-get? authorized-contracts contract-caller)) ERR-NOT-AUTHORIZED)
        
        (let (
            (current-stats (get-or-create-user-stats creator))
            (new-stats (merge current-stats {
                total-spent: (+ (get total-spent current-stats) amount)
            }))
        )
        (ok (map-set user-reputation { user: creator } new-stats)))
    )
)

(define-public (record-task-earned (worker principal) (amount uint))
    (begin
        ;; Only authorized contracts can call this
        (asserts! (default-to false (map-get? authorized-contracts contract-caller)) ERR-NOT-AUTHORIZED)
        
        (let (
            (current-stats (get-or-create-user-stats worker))
            (new-stats (merge current-stats {
                total-earned: (+ (get total-earned current-stats) amount)
            }))
        )
        (ok (map-set user-reputation { user: worker } new-stats)))
    )
)

(define-public (record-dispute (user principal) (is-worker bool) (won bool))
    (begin
        ;; Only authorized contracts can call this
        (asserts! (default-to false (map-get? authorized-contracts contract-caller)) ERR-NOT-AUTHORIZED)
        
        (let (
            (current-stats (get-or-create-user-stats user))
            (new-stats (merge current-stats {
                disputes-opened: (+ (get disputes-opened current-stats) u1),
                disputes-won: (if won (+ (get disputes-won current-stats) u1) (get disputes-won current-stats)),
                disputes-lost: (if won (get disputes-lost current-stats) (+ (get disputes-lost current-stats) u1))
            }))
        )
        (ok (map-set user-reputation { user: user } new-stats)))
    )
)
