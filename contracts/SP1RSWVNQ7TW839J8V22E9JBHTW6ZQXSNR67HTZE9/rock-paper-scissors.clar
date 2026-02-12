;; Rock Paper Scissors Contract
;; Simple rock-paper-scissors game on-chain
;; Users choose rock, paper, or scissors; contract chooses randomly
;; If user wins, gains points; tracks win rate and streaks
;; Each game generates transaction fees

;; Error codes
(define-constant ERR-INVALID-CHOICE (err u1001))
(define-constant ERR-INSUFFICIENT-FEE (err u1002))

;; Game fee (in micro-STX)
(define-constant GAME-FEE u10000)  ;; 0.01 STX per game

;; Points awarded on win
(define-constant POINTS-ON-WIN u10)  ;; 10 points per win

;; Game choices: 1 = Rock, 2 = Paper, 3 = Scissors
(define-constant ROCK u1)
(define-constant PAPER u2)
(define-constant SCISSORS u3)

;; Total games counter
(define-data-var total-games uint u0)

;; Unique users counter
(define-data-var user-count uint u0)

;; List of unique users
(define-map user-list uint principal)

;; Map to track if user is in list
(define-map user-index principal (optional uint))

;; User statistics: user -> {total-games, wins, losses, draws, total-points, win-streak, longest-streak}
(define-map user-stats principal {
    total-games: uint,
    wins: uint,
    losses: uint,
    draws: uint,
    total-points: uint,
    win-streak: uint,
    longest-streak: uint
})

;; Game history: (user, game-id) -> {user-choice, contract-choice, result, points, timestamp}
(define-map game-history (tuple (user principal) (game-id uint)) {
    user-choice: uint,
    contract-choice: uint,
    result: (string-ascii 10),
    points: uint,
    timestamp: uint
})

;; User game counter
(define-map user-game-counter principal uint)

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

;; Helper to determine game result
(define-private (determine-result (user-choice uint) (contract-choice uint))
    (if (is-eq user-choice contract-choice)
        "draw"
        (if (or 
            (and (is-eq user-choice ROCK) (is-eq contract-choice SCISSORS))
            (and (is-eq user-choice PAPER) (is-eq contract-choice ROCK))
            (and (is-eq user-choice SCISSORS) (is-eq contract-choice PAPER))
        )
        "win"
        "loss"
        )
    )
)

;; Helper to update user stats after game
(define-private (update-user-stats (user principal) (result (string-ascii 10)) (points uint) (game-time uint))
    (let ((current-stats (map-get? user-stats user)))
        (if (is-none current-stats)
            ;; First game for user
            (map-set user-stats user {
                total-games: u1,
                wins: (if (is-eq result "win") u1 u0),
                losses: (if (is-eq result "loss") u1 u0),
                draws: (if (is-eq result "draw") u1 u0),
                total-points: points,
                win-streak: (if (is-eq result "win") u1 u0),
                longest-streak: (if (is-eq result "win") u1 u0)
            })
            ;; Update existing stats
            (let ((stats (unwrap-panic current-stats)))
                (let ((current-streak (get win-streak stats))
                      (longest-streak (get longest-streak stats)))
                    ;; Calculate new win streak (reset to 0 on loss/draw, increment on win)
                    (let ((new-streak 
                        (if (is-eq result "win")
                            (+ current-streak u1)
                            u0
                        ))
                        ;; Update longest streak if current streak exceeds it
                        (new-longest (if (> new-streak longest-streak) new-streak longest-streak)))
                        (map-set user-stats user {
                            total-games: (+ (get total-games stats) u1),
                            wins: (+ (get wins stats) (if (is-eq result "win") u1 u0)),
                            losses: (+ (get losses stats) (if (is-eq result "loss") u1 u0)),
                            draws: (+ (get draws stats) (if (is-eq result "draw") u1 u0)),
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

;; Public function: Play rock paper scissors
(define-public (play-game (user-choice uint) (fee-amount uint))
    (let ((sender tx-sender)
          (game-time (var-get total-games)))
        
        ;; Validate fee
        (asserts! (>= fee-amount GAME-FEE) ERR-INSUFFICIENT-FEE)
        
        ;; Validate user choice (1-3)
        (asserts! (>= user-choice ROCK) ERR-INVALID-CHOICE)
        (asserts! (<= user-choice SCISSORS) ERR-INVALID-CHOICE)
        
        ;; Add user to list if new
        (add-user-if-new sender)
        
        ;; Generate contract choice using pseudo-random
        ;; Uses total-games + user-choice as seed for randomness
        (let ((random-seed (+ game-time user-choice))
              (contract-choice (+ (mod random-seed u3) u1)))
            
            ;; Determine result
            (let ((result (determine-result user-choice contract-choice))
                  (points-earned (if (is-eq result "win") POINTS-ON-WIN u0)))
                
                ;; Get user game counter
                (let ((user-game-id (default-to u0 (map-get? user-game-counter sender))))
                    ;; Increment counters
                    (map-set user-game-counter sender (+ user-game-id u1))
                    (var-set total-games (+ game-time u1))
                    
                    ;; Update user stats
                    (update-user-stats sender result points-earned game-time)
                    
                    ;; Get updated stats for response
                    (let ((updated-stats (unwrap-panic (map-get? user-stats sender))))
                        ;; Store in history
                        (map-set game-history (tuple (user sender) (game-id user-game-id)) {
                            user-choice: user-choice,
                            contract-choice: contract-choice,
                            result: result,
                            points: points-earned,
                            timestamp: game-time
                        })
                        
                        ;; STX is sent automatically with the transaction
                        (ok {
                            user: sender,
                            user-choice: user-choice,
                            contract-choice: contract-choice,
                            result: result,
                            points-earned: points-earned,
                            win-streak: (get win-streak updated-stats)
                        })
                    )
                )
            )
        )
    )
)

;; Public function: Claim game reward (generates additional transaction)
(define-public (claim-game-reward (fee-amount uint))
    (let ((sender tx-sender)
          (stats (map-get? user-stats sender)))
        (asserts! (is-some stats) ERR-INSUFFICIENT-FEE)
        
        (let ((user-stats-value (unwrap-panic stats)))
            ;; STX fee is sent with transaction
            (ok {
                user: sender,
                total-points: (get total-points user-stats-value),
                total-games: (get total-games user-stats-value),
                wins: (get wins user-stats-value),
                win-rate: (get win-streak user-stats-value)
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

;; Read-only: Get total games
(define-read-only (get-total-games)
    (var-get total-games)
)

;; Read-only: Get total users
(define-read-only (get-user-count)
    (var-get user-count)
)

;; Read-only: Get user by index
(define-read-only (get-user-at-index (index uint))
    (map-get? user-list index)
)

;; Read-only: Get user game history
(define-read-only (get-user-game (user principal) (game-id uint))
    (map-get? game-history (tuple (user user) (game-id game-id)))
)

;; Read-only: Get user game count
(define-read-only (get-user-game-count (user principal))
    (default-to u0 (map-get? user-game-counter user))
)

;; Read-only: Get user with stats by index (for leaderboard)
(define-read-only (get-user-at-index-with-stats (index uint))
    (match (map-get? user-list index) address
        (let ((stats (map-get? user-stats address)))
            (match stats stats-value
                (some {
                    address: address,
                    total-games: (get total-games stats-value),
                    wins: (get wins stats-value),
                    losses: (get losses stats-value),
                    draws: (get draws stats-value),
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

