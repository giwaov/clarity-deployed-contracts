;; Coin Flip Contract
;; Simple coin flipping game on-chain
;; Users choose HEADS (0) or TAILS (1), contract flips coin, if match wins points
;; Each flip generates transaction fees
;; Simple and addictive gameplay for high engagement

;; Error codes
(define-constant ERR-INVALID-CHOICE (err u1001))
(define-constant ERR-INSUFFICIENT-FEE (err u1002))

;; Coin flip fee (in micro-STX) - Lower than dice for more accessibility
(define-constant FLIP-FEE u5000)  ;; 0.005 STX per flip

;; Points awarded on win
(define-constant POINTS-ON-WIN u5)

;; Coin sides
(define-constant HEADS u0)
(define-constant TAILS u1)

;; Total flips counter
(define-data-var total-flips uint u0)

;; Unique users counter
(define-data-var user-count uint u0)

;; List of unique users
(define-map user-list uint principal)

;; Map to track if user is in list
(define-map user-index principal (optional uint))

;; User statistics: user -> {total-flips, wins, total-points, win-streak, longest-streak, heads-wins, tails-wins}
(define-map user-stats principal {
    total-flips: uint,
    wins: uint,
    total-points: uint,
    win-streak: uint,
    longest-streak: uint,
    heads-wins: uint,
    tails-wins: uint
})

;; Flip history: (user, flip-id) -> {user-choice, coin-result, won, points, timestamp}
(define-map flip-history (tuple (user principal) (flip-id uint)) {
    user-choice: uint,
    coin-result: uint,
    won: bool,
    points: uint,
    timestamp: uint
})

;; User flip counter
(define-map user-flip-counter principal uint)

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

;; Helper to update user stats after flip
(define-private (update-user-stats (user principal) (won bool) (points uint) (coin-result uint) (flip-time uint))
    (let ((current-stats (map-get? user-stats user)))
        (if (is-none current-stats)
            ;; First flip for user
            (map-set user-stats user {
                total-flips: u1,
                wins: (if won u1 u0),
                total-points: points,
                win-streak: (if won u1 u0),
                longest-streak: (if won u1 u0),
                heads-wins: (if (and won (is-eq coin-result HEADS)) u1 u0),
                tails-wins: (if (and won (is-eq coin-result TAILS)) u1 u0)
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
                            total-flips: (+ (get total-flips stats) u1),
                            wins: (+ (get wins stats) (if won u1 u0)),
                            total-points: (+ (get total-points stats) points),
                            win-streak: new-streak,
                            longest-streak: new-longest,
                            heads-wins: (+ (get heads-wins stats) (if (and won (is-eq coin-result HEADS)) u1 u0)),
                            tails-wins: (+ (get tails-wins stats) (if (and won (is-eq coin-result TAILS)) u1 u0))
                        })
                    )
                )
            )
        )
    )
)

;; Public function: Flip coin
(define-public (flip-coin (user-choice uint) (fee-amount uint))
    (let ((sender tx-sender)
          (flip-time (var-get total-flips)))
        
        ;; Validate fee
        (asserts! (>= fee-amount FLIP-FEE) ERR-INSUFFICIENT-FEE)
        
        ;; Validate user choice (0 = HEADS, 1 = TAILS)
        (asserts! (or (is-eq user-choice HEADS) (is-eq user-choice TAILS)) ERR-INVALID-CHOICE)
        
        ;; Add user to list if new
        (add-user-if-new sender)
        
        ;; Generate coin result using pseudo-random
        ;; Uses total-flips + user-choice + stacks-block-height for better randomness
        (let ((random-seed (+ (+ flip-time user-choice) stacks-block-height))
              (coin-result (mod random-seed u2)))
            
            ;; Check if user won
            (let ((won (is-eq user-choice coin-result))
                  (points-earned (if won POINTS-ON-WIN u0)))
                
                ;; Get user flip counter
                (let ((user-flip-id (default-to u0 (map-get? user-flip-counter sender))))
                    ;; Increment counters
                    (map-set user-flip-counter sender (+ user-flip-id u1))
                    (var-set total-flips (+ flip-time u1))
                    
                    ;; Update user stats
                    (update-user-stats sender won points-earned coin-result flip-time)
                    
                    ;; Get updated stats for response
                    (let ((updated-stats (unwrap-panic (map-get? user-stats sender))))
                        ;; Store in history
                        (map-set flip-history (tuple (user sender) (flip-id user-flip-id)) {
                            user-choice: user-choice,
                            coin-result: coin-result,
                            won: won,
                            points: points-earned,
                            timestamp: flip-time
                        })
                        
                        ;; STX is sent automatically with the transaction
                        (ok {
                            user: sender,
                            user-choice: user-choice,
                            coin-result: coin-result,
                            won: won,
                            points-earned: points-earned,
                            win-streak: (get win-streak updated-stats),
                            total-wins: (get wins updated-stats)
                        })
                    )
                )
            )
        )
    )
)

;; Public function: Flip heads (convenience function)
(define-public (flip-heads)
    (flip-coin HEADS FLIP-FEE)
)

;; Public function: Flip tails (convenience function)
(define-public (flip-tails)
    (flip-coin TAILS FLIP-FEE)
)

;; Public function: Claim flip reward (generates additional transaction)
(define-public (claim-flip-reward (fee-amount uint))
    (let ((sender tx-sender)
          (stats (map-get? user-stats sender)))
        (asserts! (is-some stats) ERR-INSUFFICIENT-FEE)
        
        (let ((user-stats-value (unwrap-panic stats)))
            ;; STX fee is sent with transaction
            (ok {
                user: sender,
                total-points: (get total-points user-stats-value),
                total-flips: (get total-flips user-stats-value),
                wins: (get wins user-stats-value),
                win-streak: (get win-streak user-stats-value),
                longest-streak: (get longest-streak user-stats-value)
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

;; Read-only: Get total flips
(define-read-only (get-total-flips)
    (var-get total-flips)
)

;; Read-only: Get total users
(define-read-only (get-user-count)
    (var-get user-count)
)

;; Read-only: Get user by index
(define-read-only (get-user-at-index (index uint))
    (map-get? user-list index)
)

;; Read-only: Get user flip history
(define-read-only (get-user-flip (user principal) (flip-id uint))
    (map-get? flip-history (tuple (user user) (flip-id flip-id)))
)

;; Read-only: Get user flip count
(define-read-only (get-user-flip-count (user principal))
    (default-to u0 (map-get? user-flip-counter user))
)

;; Read-only: Get flip fee
(define-read-only (get-flip-fee)
    FLIP-FEE
)

;; Read-only: Get user with stats by index (for leaderboard)
(define-read-only (get-user-at-index-with-stats (index uint))
    (match (map-get? user-list index) address
        (let ((stats (map-get? user-stats address)))
            (match stats stats-value
                (some {
                    address: address,
                    total-flips: (get total-flips stats-value),
                    wins: (get wins stats-value),
                    total-points: (get total-points stats-value),
                    win-streak: (get win-streak stats-value),
                    longest-streak: (get longest-streak stats-value),
                    heads-wins: (get heads-wins stats-value),
                    tails-wins: (get tails-wins stats-value)
                })
                none
            )
        )
        none
    )
)

;; Read-only: Calculate win rate percentage (scaled by 100 for precision)
;; Returns win rate as percentage * 100 (e.g., 4500 = 45.00%)
(define-read-only (get-user-win-rate (user principal))
    (match (map-get? user-stats user) stats-value
        (let ((total (get total-flips stats-value))
              (wins (get wins stats-value)))
            (if (is-eq total u0)
                u0
                ;; Calculate (wins * 10000) / total for 2 decimal precision
                (/ (* wins u10000) total)
            )
        )
        u0
    )
)
