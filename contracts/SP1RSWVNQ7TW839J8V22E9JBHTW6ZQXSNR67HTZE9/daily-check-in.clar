;; Daily Check-in Contract
;; On-chain daily check-in system with streak tracking
;; Users check in daily by paying fees; tracks streaks and rewards
;; Each check-in generates transaction fees

;; Error codes
(define-constant ERR-ALREADY-CHECKED-IN (err u1001))
(define-constant ERR-INSUFFICIENT-FEE (err u1002))
(define-constant ERR-NO-REWARD-AVAILABLE (err u1003))

;; Check-in fee (in micro-STX)
(define-constant CHECK-IN-FEE u10000)  ;; 0.01 STX per check-in

;; Streak milestones for rewards (in days)
(define-constant MILESTONE-7-DAYS u7)
(define-constant MILESTONE-30-DAYS u30)
(define-constant MILESTONE-100-DAYS u100)

;; Points per check-in
(define-constant POINTS-PER-CHECK-IN u1)

;; Total check-ins counter
(define-data-var total-check-ins uint u0)

;; Unique users counter
(define-data-var user-count uint u0)

;; List of unique users
(define-map user-list uint principal)

;; Map to track if user is in list
(define-map user-index principal (optional uint))

;; User check-in data: user -> {total-check-ins, current-streak, longest-streak, last-check-in-day, total-points}
(define-map user-check-ins principal {
    total-check-ins: uint,
    current-streak: uint,
    longest-streak: uint,
    last-check-in-day: uint,
    total-points: uint
})

;; Check-in history: (user, check-in-id) -> {day, streak, points}
(define-map check-in-history (tuple (user principal) (check-in-id uint)) {
    day: uint,
    streak: uint,
    points: uint
})

;; User check-in counter
(define-map user-check-in-counter principal uint)

;; Milestone rewards claimed: (user, milestone) -> claimed
(define-map milestone-claims (tuple (user principal) (milestone uint)) bool)

;; Helper to add user to list if new
(define-private (add-user-if-new (user principal))
    (let ((existing-index (map-get? user-index user)))
        (if (is-none existing-index)
            ;; New user, add to list
            (let ((new-index (var-get user-count)))
                (var-set user-count (+ new-index u1))
                (map-set user-list new-index user)
                (map-set user-index user (some new-index))
                true
            )
            ;; Already in list
            false
        )
    )
)

;; Helper to calculate current day (using total-check-ins as day counter)
;; This provides a simple day tracking mechanism based on total check-ins
(define-private (get-current-day)
    (var-get total-check-ins)
)

;; Helper to update user check-in stats
(define-private (update-user-stats (user principal) (fee uint) (current-day uint))
    (let ((current-stats (map-get? user-check-ins user)))
        (if (is-none current-stats)
            ;; First check-in for user
            (map-set user-check-ins user {
                total-check-ins: u1,
                current-streak: u1,
                longest-streak: u1,
                last-check-in-day: current-day,
                total-points: POINTS-PER-CHECK-IN
            })
            ;; Update existing stats
            (let ((stats (unwrap-panic current-stats)))
                (let ((last-day (get last-check-in-day stats))
                      (current-streak (get current-streak stats))
                      (longest-streak (get longest-streak stats)))
                    ;; Check if streak continues (consecutive days)
                    ;; Streak breaks if more than 1 day has passed
                    (let ((new-streak 
                        (if (is-eq current-day last-day)
                            ;; Same day - streak continues
                            current-streak
                            (if (is-eq current-day (+ last-day u1))
                                ;; Consecutive day - increment streak
                                (+ current-streak u1)
                                ;; Streak broken - reset to 1
                                u1
                            )
                        ))
                        (new-longest (if (> new-streak longest-streak) new-streak longest-streak)))
                        (map-set user-check-ins user {
                            total-check-ins: (+ (get total-check-ins stats) u1),
                            current-streak: new-streak,
                            longest-streak: new-longest,
                            last-check-in-day: current-day,
                            total-points: (+ (get total-points stats) POINTS-PER-CHECK-IN)
                        })
                    )
                )
            )
        )
    )
)

;; Public function: Daily check-in
(define-public (check-in (fee-amount uint))
    (let ((sender tx-sender)
          (current-day (get-current-day)))
        
        ;; Validate fee
        (asserts! (>= fee-amount CHECK-IN-FEE) ERR-INSUFFICIENT-FEE)
        
        ;; Get user stats
        (let ((user-stats (map-get? user-check-ins sender)))
            (match user-stats stats-value
                ;; User has checked in before
                (let ((stats stats-value)
                      (last-day (get last-check-in-day stats)))
                    ;; Check if already checked in today
                    (asserts! (not (is-eq current-day last-day)) ERR-ALREADY-CHECKED-IN)
                )
                ;; New user - no previous check-in
                true
            )
        )
        
        ;; Add user to list if new
        (add-user-if-new sender)
        
        ;; Get user check-in counter
        (let ((user-check-in-id (default-to u0 (map-get? user-check-in-counter sender))))
            ;; Increment counters
            (map-set user-check-in-counter sender (+ user-check-in-id u1))
            (var-set total-check-ins (+ current-day u1))
            
            ;; Update user stats
            (update-user-stats sender fee-amount current-day)
            
            ;; Get updated stats for response
            (let ((updated-stats (unwrap-panic (map-get? user-check-ins sender))))
                ;; Store in history
                (map-set check-in-history (tuple (user sender) (check-in-id user-check-in-id)) {
                    day: current-day,
                    streak: (get current-streak updated-stats),
                    points: POINTS-PER-CHECK-IN
                })
                
                ;; STX is sent automatically with the transaction
                (ok {
                    user: sender,
                    day: current-day,
                    current-streak: (get current-streak updated-stats),
                    longest-streak: (get longest-streak updated-stats),
                    total-check-ins: (get total-check-ins updated-stats)
                })
            )
        )
    )
)

;; Public function: Claim milestone reward
(define-public (claim-milestone-reward (milestone uint) (fee-amount uint))
    (let ((sender tx-sender))
        ;; Validate fee
        (asserts! (>= fee-amount CHECK-IN-FEE) ERR-INSUFFICIENT-FEE)
        
        ;; Validate milestone
        (asserts! (or (is-eq milestone MILESTONE-7-DAYS) 
                      (is-eq milestone MILESTONE-30-DAYS) 
                      (is-eq milestone MILESTONE-100-DAYS)) ERR-NO-REWARD-AVAILABLE)
        
        ;; Check if already claimed
        (let ((already-claimed (default-to false (map-get? milestone-claims (tuple (user sender) (milestone milestone))))))
            (asserts! (not already-claimed) ERR-NO-REWARD-AVAILABLE)
        )
        
        ;; Get user stats
        (let ((user-stats-opt (map-get? user-check-ins sender)))
            (asserts! (is-some user-stats-opt) ERR-NO-REWARD-AVAILABLE)
            (let ((stats (unwrap-panic user-stats-opt))
                  (current-streak (get current-streak stats)))
                ;; Check if user reached milestone
                (asserts! (>= current-streak milestone) ERR-NO-REWARD-AVAILABLE)
                
                ;; Mark milestone as claimed
                (map-set milestone-claims (tuple (user sender) (milestone milestone)) true)
                
                ;; STX fee is sent with transaction
                (ok {
                    user: sender,
                    milestone: milestone,
                    current-streak: current-streak,
                    claimed: true
                })
            )
        )
    )
)

;; ============================================
;; Read-only functions for contract queries
;; ============================================

;; Read-only: Get user check-in statistics
(define-read-only (get-user-stats (user principal))
    (map-get? user-check-ins user)
)

;; Read-only: Get total check-ins
(define-read-only (get-total-check-ins)
    (var-get total-check-ins)
)

;; Read-only: Get total users
(define-read-only (get-user-count)
    (var-get user-count)
)

;; Read-only: Get user by index
(define-read-only (get-user-at-index (index uint))
    (map-get? user-list index)
)

;; Read-only: Get user check-in history
(define-read-only (get-user-check-in (user principal) (check-in-id uint))
    (map-get? check-in-history (tuple (user user) (check-in-id check-in-id)))
)

;; Read-only: Get user check-in count
(define-read-only (get-user-check-in-count (user principal))
    (default-to u0 (map-get? user-check-in-counter user))
)

;; Read-only: Check if user can check in today
(define-read-only (can-check-in (user principal))
    (let ((current-day (get-current-day))
          (stats (map-get? user-check-ins user)))
        (match stats stats-value
            (let ((last-day (get last-check-in-day stats-value)))
                (not (is-eq current-day last-day))
            )
            ;; New user can always check in
            true
        )
    )
)

;; Read-only: Check if milestone is claimed
(define-read-only (is-milestone-claimed (user principal) (milestone uint))
    (default-to false (map-get? milestone-claims (tuple (user user) (milestone milestone))))
)

;; Read-only: Get user with stats by index (for leaderboard)
(define-read-only (get-user-at-index-with-stats (index uint))
    (match (map-get? user-list index) address
        (let ((stats (map-get? user-check-ins address)))
            (match stats stats-value
                (some {
                    address: address,
                    total-check-ins: (get total-check-ins stats-value),
                    current-streak: (get current-streak stats-value),
                    longest-streak: (get longest-streak stats-value),
                    total-points: (get total-points stats-value)
                })
                none
            )
        )
        none
    )
)
