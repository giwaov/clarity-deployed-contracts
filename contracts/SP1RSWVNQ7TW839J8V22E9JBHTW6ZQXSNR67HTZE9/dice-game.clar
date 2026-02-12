;; Dice Game Contract
;; Simple dice rolling game on-chain
;; Users choose a number (1-6), contract rolls dice, if match wins points
;; Each roll generates transaction fees
;; Simple and direct gameplay for high engagement

;; Error codes
(define-constant ERR-INVALID-NUMBER (err u1001))
(define-constant ERR-INSUFFICIENT-FEE (err u1002))

;; Dice roll fee (in micro-STX)
(define-constant DICE-FEE u10000)  ;; 0.01 STX per roll

;; Points awarded on win (10 points per correct guess)
(define-constant POINTS-ON-WIN u10)

;; Dice number range
(define-constant DICE-MIN u1)
(define-constant DICE-MAX u6)

;; Total rolls counter
(define-data-var total-rolls uint u0)

;; Unique users counter
(define-data-var user-count uint u0)

;; List of unique users
(define-map user-list uint principal)

;; Map to track if user is in list
(define-map user-index principal (optional uint))

;; User statistics: user -> {total-rolls, wins, total-points, win-streak, longest-streak}
(define-map user-stats principal {
    total-rolls: uint,
    wins: uint,
    total-points: uint,
    win-streak: uint,
    longest-streak: uint
})

;; Roll history: (user, roll-id) -> {user-choice, dice-result, won, points, timestamp}
(define-map roll-history (tuple (user principal) (roll-id uint)) {
    user-choice: uint,
    dice-result: uint,
    won: bool,
    points: uint,
    timestamp: uint
})

;; User roll counter
(define-map user-roll-counter principal uint)

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

;; Helper to update user stats after roll
(define-private (update-user-stats (user principal) (won bool) (points uint) (roll-time uint))
    (let ((current-stats (map-get? user-stats user)))
        (if (is-none current-stats)
            ;; First roll for user
            (map-set user-stats user {
                total-rolls: u1,
                wins: (if won u1 u0),
                total-points: points,
                win-streak: (if won u1 u0),
                longest-streak: (if won u1 u0)
            })
            ;; Update existing stats
            (let ((stats (unwrap-panic current-stats)))
                (let ((current-streak (get win-streak stats))
                      (longest-streak (get longest-streak stats)))
                    ;; Update win streak: increment if won, reset to 0 if lost
                    (let ((new-streak 
                        (if won
                            (+ current-streak u1)
                            u0
                        ))
                        (new-longest (if (> new-streak longest-streak) new-streak longest-streak)))
                        (map-set user-stats user {
                            total-rolls: (+ (get total-rolls stats) u1),
                            wins: (+ (get wins stats) (if won u1 u0)),
                            total-points: (+ (get total-points stats) points),
                            win-streak: new-streak,
                            longest-streak: new-longest
                        })
                    )
                )
            )
        )
    )
)

;; Public function: Roll dice
(define-public (roll-dice (user-choice uint) (fee-amount uint))
    (let ((sender tx-sender)
          (roll-time (var-get total-rolls)))
        
        ;; Validate fee
        (asserts! (>= fee-amount DICE-FEE) ERR-INSUFFICIENT-FEE)
        
        ;; Validate user choice (1-6)
        (asserts! (>= user-choice DICE-MIN) ERR-INVALID-NUMBER)
        (asserts! (<= user-choice DICE-MAX) ERR-INVALID-NUMBER)
        
        ;; Add user to list if new
        (add-user-if-new sender)
        
        ;; Generate dice result using pseudo-random
        ;; Uses total-rolls + user-choice as seed for deterministic but unpredictable result
        (let ((random-seed (+ roll-time user-choice))
              (dice-result (+ (mod random-seed u6) u1)))
            
            ;; Check if user won
            (let ((won (is-eq user-choice dice-result))
                  (points-earned (if won POINTS-ON-WIN u0)))
                
                ;; Get user roll counter
                (let ((user-roll-id (default-to u0 (map-get? user-roll-counter sender))))
                    ;; Increment counters
                    (map-set user-roll-counter sender (+ user-roll-id u1))
                    (var-set total-rolls (+ roll-time u1))
                    
                    ;; Update user stats
                    (update-user-stats sender won points-earned roll-time)
                    
                    ;; Get updated stats for response
                    (let ((updated-stats (unwrap-panic (map-get? user-stats sender))))
                        ;; Store in history
                        (map-set roll-history (tuple (user sender) (roll-id user-roll-id)) {
                            user-choice: user-choice,
                            dice-result: dice-result,
                            won: won,
                            points: points-earned,
                            timestamp: roll-time
                        })
                        
                        ;; STX is sent automatically with the transaction
                        (ok {
                            user: sender,
                            user-choice: user-choice,
                            dice-result: dice-result,
                            won: won,
                            points-earned: points-earned,
                            win-streak: (get win-streak updated-stats)
                        })
                    )
                )
            )
        )
    )
)

;; Public function: Claim dice reward (generates additional transaction)
(define-public (claim-dice-reward (fee-amount uint))
    (let ((sender tx-sender)
          (stats (map-get? user-stats sender)))
        (asserts! (is-some stats) ERR-INSUFFICIENT-FEE)
        
        (let ((user-stats-value (unwrap-panic stats)))
            ;; STX fee is sent with transaction
            (ok {
                user: sender,
                total-points: (get total-points user-stats-value),
                total-rolls: (get total-rolls user-stats-value),
                wins: (get wins user-stats-value),
                win-streak: (get win-streak user-stats-value)
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

;; Read-only: Get total rolls
(define-read-only (get-total-rolls)
    (var-get total-rolls)
)

;; Read-only: Get total users
(define-read-only (get-user-count)
    (var-get user-count)
)

;; Read-only: Get user by index
(define-read-only (get-user-at-index (index uint))
    (map-get? user-list index)
)

;; Read-only: Get user roll history
(define-read-only (get-user-roll (user principal) (roll-id uint))
    (map-get? roll-history (tuple (user user) (roll-id roll-id)))
)

;; Read-only: Get user roll count
(define-read-only (get-user-roll-count (user principal))
    (default-to u0 (map-get? user-roll-counter user))
)

;; Read-only: Get user with stats by index (for leaderboard)
(define-read-only (get-user-at-index-with-stats (index uint))
    (match (map-get? user-list index) address
        (let ((stats (map-get? user-stats address)))
            (match stats stats-value
                (some {
                    address: address,
                    total-rolls: (get total-rolls stats-value),
                    wins: (get wins stats-value),
                    total-points: (get total-points stats-value),
                    win-streak: (get win-streak stats-value),
                    longest-streak: (get longest-streak stats-value)
                })
                none
            )
        )
        none
    )
)
