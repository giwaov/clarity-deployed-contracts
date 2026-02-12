;; Quest System Contract
;; On-chain quest/mission system for high engagement
;; Users complete quests by paying fees; tracks progress and rewards
;; Each quest completion generates transaction fees

;; Error codes
(define-constant ERR-INVALID-QUEST (err u1001))
(define-constant ERR-QUEST-ON-COOLDOWN (err u1002))
(define-constant ERR-INSUFFICIENT-FEE (err u1003))
(define-constant ERR-QUEST-ALREADY-COMPLETED (err u1004))
(define-constant ERR-NO-REWARD-AVAILABLE (err u1005))

;; Quest fees (in micro-STX)
(define-constant FEE-DAILY-QUEST u10000)      ;; 0.01 STX
(define-constant FEE-WEEKLY-QUEST u50000)     ;; 0.05 STX
(define-constant FEE-SPECIAL-QUEST u20000)    ;; 0.02 STX
(define-constant FEE-CLAIM-REWARD u10000)     ;; 0.01 STX

;; Cooldown periods (based on total quests completed)
;; Daily: 144 quests (approximately daily frequency)
;; Weekly: 1008 quests (approximately weekly frequency)
(define-constant DAILY-COOLDOWN u144)
(define-constant WEEKLY-COOLDOWN u1008)

;; Points per quest type
(define-constant POINTS-DAILY u10)
(define-constant POINTS-WEEKLY u50)
(define-constant POINTS-SPECIAL u20)

;; Total quests counter
(define-data-var total-quests uint u0)

;; Unique users counter
(define-data-var user-count uint u0)

;; List of unique users
(define-map user-list uint principal)

;; Map to track if user is in list
(define-map user-index principal (optional uint))

;; User statistics: user -> {total-quests, total-points, total-spent, quest-master-level}
(define-map user-stats principal {
    total-quests: uint,
    total-points: uint,
    total-spent: uint,
    quest-master-level: uint
})

;; Quest completion history: (user, quest-id) -> {quest-type, points, timestamp}
(define-map quest-history (tuple (user principal) (quest-id uint)) {
    quest-type: (string-ascii 20),
    points: uint,
    timestamp: uint
})

;; User quest counter
(define-map user-quest-counter principal uint)

;; Last completion time for daily quest: user -> quest-id (for cooldown tracking)
(define-map last-daily-quest principal uint)

;; Last completion time for weekly quest: user -> quest-id (for cooldown tracking)
(define-map last-weekly-quest principal uint)

;; Quest type statistics: quest-type -> {count, total-fees, total-points}
(define-map quest-type-stats (string-ascii 20) {
    count: uint,
    total-fees: uint,
    total-points: uint
})

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

;; Helper to update user stats
(define-private (update-user-stats (user principal) (fee uint) (points uint) (quest-time uint))
    (let ((current-stats (map-get? user-stats user)))
        (if (is-none current-stats)
            ;; First quest for user
            (map-set user-stats user {
                total-quests: u1,
                total-points: points,
                total-spent: fee,
                quest-master-level: u1
            })
            ;; Update existing stats
            (let ((stats (unwrap-panic current-stats)))
                (let ((new-points (+ (get total-points stats) points))
                      (new-level (+ u1 (/ new-points u100))))  ;; Level up every 100 points (Quest Master progression)
                    (map-set user-stats user {
                        total-quests: (+ (get total-quests stats) u1),
                        total-points: new-points,
                        total-spent: (+ (get total-spent stats) fee),
                        quest-master-level: new-level
                    })
                )
            )
        )
    )
)

;; Helper to update quest type stats
(define-private (update-quest-type-stats (quest-type (string-ascii 20)) (fee uint) (points uint))
    (let ((current-stats (map-get? quest-type-stats quest-type)))
        (if (is-none current-stats)
            ;; First time this quest type is completed
            (map-set quest-type-stats quest-type {
                count: u1,
                total-fees: fee,
                total-points: points
            })
            ;; Update existing stats
            (let ((stats (unwrap-panic current-stats)))
                (map-set quest-type-stats quest-type {
                    count: (+ (get count stats) u1),
                    total-fees: (+ (get total-fees stats) fee),
                    total-points: (+ (get total-points stats) points)
                })
            )
        )
    )
)

;; Helper to check cooldown (using total-quests as time reference)
(define-private (check-cooldown (user principal) (quest-type (string-ascii 20)) (current-quest-id uint))
    (if (is-eq quest-type "daily")
        (let ((last-completion (default-to u0 (map-get? last-daily-quest user))))
            (if (>= current-quest-id (+ last-completion DAILY-COOLDOWN))
                true
                false
            )
        )
        (if (is-eq quest-type "weekly")
            (let ((last-completion (default-to u0 (map-get? last-weekly-quest user))))
                (if (>= current-quest-id (+ last-completion WEEKLY-COOLDOWN))
                    true
                    false
                )
            )
            ;; Special quests have no cooldown
            true
        )
    )
)

;; Main function to complete a quest
(define-public (complete-quest (quest-type (string-ascii 20)) (fee-amount uint))
    (let ((sender tx-sender)
          (quest-time (var-get total-quests)))
        
        ;; Validate quest type and fee
        (asserts! (> fee-amount u0) ERR-INSUFFICIENT-FEE)
        
        ;; Check quest type and get required fee and points
        (let ((required-fee 
            (if (is-eq quest-type "daily")
                FEE-DAILY-QUEST
                (if (is-eq quest-type "weekly")
                    FEE-WEEKLY-QUEST
                    (if (is-eq quest-type "special")
                        FEE-SPECIAL-QUEST
                        u0
                    )
                )
            )))
            (asserts! (> required-fee u0) ERR-INVALID-QUEST)
            (asserts! (>= fee-amount required-fee) ERR-INSUFFICIENT-FEE)
            
            ;; Check cooldown using total-quests as time reference
            (asserts! (check-cooldown sender quest-type quest-time) ERR-QUEST-ON-COOLDOWN)
            
            ;; Add user to list if new
            (add-user-if-new sender)
            
            ;; Get quest points
            (let ((quest-points
                (if (is-eq quest-type "daily")
                    POINTS-DAILY
                    (if (is-eq quest-type "weekly")
                        POINTS-WEEKLY
                        POINTS-SPECIAL
                    )
                )))
                
                ;; Get user quest counter
                (let ((user-quest-id (default-to u0 (map-get? user-quest-counter sender))))
                    ;; Increment counters
                    (map-set user-quest-counter sender (+ user-quest-id u1))
                    (var-set total-quests (+ quest-time u1))
                    
                    ;; Update last completion time for cooldown
                    (if (is-eq quest-type "daily")
                        (map-set last-daily-quest sender quest-time)
                        (if (is-eq quest-type "weekly")
                            (map-set last-weekly-quest sender quest-time)
                            true
                        )
                    )
                    
                    ;; Store in history
                    (map-set quest-history (tuple (user sender) (quest-id user-quest-id)) {
                        quest-type: quest-type,
                        points: quest-points,
                        timestamp: quest-time
                    })
                    
                    ;; Update statistics
                    (update-user-stats sender fee-amount quest-points quest-time)
                    (update-quest-type-stats quest-type fee-amount quest-points)
                    
                    ;; STX is sent automatically with the transaction
                    (ok {
                        user: sender,
                        quest-type: quest-type,
                        points-earned: quest-points,
                        quest-id: user-quest-id
                    })
                )
            )
        )
    )
)

;; Public function: Complete daily quest
(define-public (complete-daily-quest)
    (complete-quest "daily" FEE-DAILY-QUEST)
)

;; Public function: Complete weekly quest
(define-public (complete-weekly-quest)
    (complete-quest "weekly" FEE-WEEKLY-QUEST)
)

;; Public function: Complete special quest
(define-public (complete-special-quest)
    (complete-quest "special" FEE-SPECIAL-QUEST)
)

;; Public function: Claim reward (generates additional transaction)
(define-public (claim-quest-reward)
    (let ((sender tx-sender)
          (stats (map-get? user-stats sender)))
        (asserts! (is-some stats) ERR-NO-REWARD-AVAILABLE)
        
        (let ((user-stats-value (unwrap-panic stats)))
            ;; STX fee is sent with transaction
            (ok {
                user: sender,
                total-points: (get total-points user-stats-value),
                quest-master-level: (get quest-master-level user-stats-value),
                total-quests: (get total-quests user-stats-value)
            })
        )
    )
)

;; ============================================
;; Read-only functions for contract queries
;; ============================================

;; Read-only: Get user statistics
(define-read-only (get-user-stats (user principal))
    (map-get? user-stats user)
)

;; Read-only: Get quest type statistics
(define-read-only (get-quest-type-stats (quest-type (string-ascii 20)))
    (map-get? quest-type-stats quest-type)
)

;; Read-only: Get total quests
(define-read-only (get-total-quests)
    (var-get total-quests)
)

;; Read-only: Get total users
(define-read-only (get-user-count)
    (var-get user-count)
)

;; Read-only: Get user by index
(define-read-only (get-user-at-index (index uint))
    (map-get? user-list index)
)

;; Read-only: Get user quest history
(define-read-only (get-user-quest (user principal) (quest-id uint))
    (map-get? quest-history (tuple (user user) (quest-id quest-id)))
)

;; Read-only: Get user quest count
(define-read-only (get-user-quest-count (user principal))
    (default-to u0 (map-get? user-quest-counter user))
)

;; Read-only: Check if user can complete daily quest
(define-read-only (can-complete-daily-quest (user principal))
    (let ((current-quest-id (var-get total-quests))
          (last-completion (default-to u0 (map-get? last-daily-quest user))))
        (>= current-quest-id (+ last-completion DAILY-COOLDOWN))
    )
)

;; Read-only: Check if user can complete weekly quest
(define-read-only (can-complete-weekly-quest (user principal))
    (let ((current-quest-id (var-get total-quests))
          (last-completion (default-to u0 (map-get? last-weekly-quest user))))
        (>= current-quest-id (+ last-completion WEEKLY-COOLDOWN))
    )
)

;; Read-only: Get user with stats by index (for leaderboard)
(define-read-only (get-user-at-index-with-stats (index uint))
    (match (map-get? user-list index) address
        (let ((stats (map-get? user-stats address)))
            (match stats stats-value
                (some {
                    address: address,
                    total-quests: (get total-quests stats-value),
                    total-points: (get total-points stats-value),
                    quest-master-level: (get quest-master-level stats-value),
                    total-spent: (get total-spent stats-value)
                })
                none
            )
        )
        none
    )
)
