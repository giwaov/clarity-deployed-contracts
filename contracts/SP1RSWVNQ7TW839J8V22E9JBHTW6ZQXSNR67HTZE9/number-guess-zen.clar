;; Number Guess Zen Contract
;; Infinite attempts mode - Casual gameplay
;; Guess a number between 0-1000
;; No fees, just gas - pure on-chain activity
;; Optional hint available for 0.003 STX

;; Error codes
(define-constant ERR-NO-ACTIVE-GAME (err u1001))
(define-constant ERR-GAME-ALREADY-ACTIVE (err u1002))
(define-constant ERR-INVALID-NUMBER (err u1003))
(define-constant ERR-INSUFFICIENT-FEE (err u1004))
(define-constant ERR-HINT-ALREADY-USED (err u1005))

;; Constants
(define-constant MIN-NUMBER u0)
(define-constant MAX-NUMBER u1000)
(define-constant HINT-FEE u3000)  ;; 0.003 STX

;; Total games counter
(define-data-var total-games uint u0)

;; Unique players counter
(define-data-var player-count uint u0)

;; List of unique players
(define-map player-list uint principal)

;; Map to track if player is in list
(define-map player-index principal (optional uint))

;; Game state per player
(define-map active-games principal {
    secret-number: uint,
    attempts: uint,
    hint-used: bool,
    game-id: uint
})

;; Player statistics
(define-map player-stats principal {
    total-games: uint,
    total-attempts: uint,
    best-attempts: uint,  ;; Lowest number of attempts to win
    current-streak: uint,
    longest-streak: uint
})

;; Game history: (player, game-id) -> {secret-number, attempts, won, hint-used}
(define-map game-history (tuple (player principal) (game-id uint)) {
    secret-number: uint,
    attempts: uint,
    won: bool,
    hint-used: bool
})

;; Player game counter
(define-map player-game-counter principal uint)

;; Helper to add player to list if new
(define-private (add-player-if-new (player principal))
    (let ((existing-index (map-get? player-index player)))
        (if (is-none existing-index)
            (let ((new-index (var-get player-count)))
                (var-set player-count (+ new-index u1))
                (map-set player-list new-index player)
                (map-set player-index player (some new-index))
                true
            )
            false
        )
    )
)

;; Helper to generate random number between MIN-NUMBER and MAX-NUMBER
(define-private (generate-secret-number (seed uint))
    (let ((random-seed (+ (+ (* seed u997) stacks-block-height) (var-get player-count))))
        (+ MIN-NUMBER (mod random-seed (+ u1 (- MAX-NUMBER MIN-NUMBER))))
    )
)

;; Public function: Start new game
(define-public (start-game)
    (let ((player tx-sender))
        ;; Check if player already has active game
        (asserts! (is-none (map-get? active-games player)) ERR-GAME-ALREADY-ACTIVE)
        
        ;; Add player to list if new
        (add-player-if-new player)
        
        ;; Get game counter
        (let ((game-counter (var-get total-games)))
            ;; Generate secret number
            (let ((secret (generate-secret-number game-counter)))
                ;; Create new game
                (map-set active-games player {
                    secret-number: secret,
                    attempts: u0,
                    hint-used: false,
                    game-id: game-counter
                })
                
                ;; Increment total games
                (var-set total-games (+ game-counter u1))
                
                (ok {
                    game-id: game-counter,
                    message: "Game started! Guess a number between 0-1000",
                    min: MIN-NUMBER,
                    max: MAX-NUMBER
                })
            )
        )
    )
)

;; Public function: Make a guess
(define-public (guess (number uint))
    (let ((player tx-sender))
        ;; Validate number range
        (asserts! (>= number MIN-NUMBER) ERR-INVALID-NUMBER)
        (asserts! (<= number MAX-NUMBER) ERR-INVALID-NUMBER)
        
        ;; Get active game
        (let ((game-opt (map-get? active-games player)))
            (asserts! (is-some game-opt) ERR-NO-ACTIVE-GAME)
            (let ((game (unwrap-panic game-opt)))
                (let ((secret (get secret-number game))
                      (attempts (get attempts game))
                      (game-id (get game-id game))
                      (hint-used (get hint-used game)))
                    
                    ;; Increment attempts
                    (let ((new-attempts (+ attempts u1)))
                        (if (is-eq number secret)
                            ;; Correct guess! End game
                            (begin
                                ;; Remove active game
                                (map-delete active-games player)
                                
                                ;; Update stats
                                (let ((stats-opt (map-get? player-stats player)))
                                    (if (is-none stats-opt)
                                        ;; First game
                                        (map-set player-stats player {
                                            total-games: u1,
                                            total-attempts: new-attempts,
                                            best-attempts: new-attempts,
                                            current-streak: u1,
                                            longest-streak: u1
                                        })
                                        ;; Update existing stats
                                        (let ((stats (unwrap-panic stats-opt)))
                                            (let ((current-streak (get current-streak stats))
                                                  (longest-streak (get longest-streak stats))
                                                  (best-attempts (get best-attempts stats)))
                                                (let ((new-streak (+ current-streak u1))
                                                      (new-longest (if (> (+ current-streak u1) longest-streak) 
                                                                      (+ current-streak u1) 
                                                                      longest-streak))
                                                      (new-best (if (< new-attempts best-attempts) 
                                                                   new-attempts 
                                                                   best-attempts)))
                                                    (map-set player-stats player {
                                                        total-games: (+ (get total-games stats) u1),
                                                        total-attempts: (+ (get total-attempts stats) new-attempts),
                                                        best-attempts: new-best,
                                                        current-streak: new-streak,
                                                        longest-streak: new-longest
                                                    })
                                                )
                                            )
                                        )
                                    )
                                )
                                
                                ;; Save to history
                                (let ((player-game-id (default-to u0 (map-get? player-game-counter player))))
                                    (map-set player-game-counter player (+ player-game-id u1))
                                    (map-set game-history (tuple (player player) (game-id player-game-id)) {
                                        secret-number: secret,
                                        attempts: new-attempts,
                                        won: true,
                                        hint-used: hint-used
                                    })
                                )
                                
                                (ok {
                                    result: "correct",
                                    attempts: new-attempts,
                                    message: "Congratulations!",
                                    hint-used: hint-used,
                                    number: (some secret)
                                })
                            )
                            ;; Wrong guess - update attempts and give hint
                            (begin
                                ;; Update game state
                                (map-set active-games player {
                                    secret-number: secret,
                                    attempts: new-attempts,
                                    hint-used: hint-used,
                                    game-id: game-id
                                })
                                
                                (ok {
                                    result: (if (> number secret) "lower" "higher"),
                                    attempts: new-attempts,
                                    message: (if (> number secret) 
                                               "Try lower!" 
                                               "Try higher!"),
                                    hint-used: hint-used,
                                    number: none
                                })
                            )
                        )
                    )
                )
            )
        )
    )
)

;; Public function: Get hint (costs 0.003 STX, only 1 per game)
;; Reveals: Parity (even/odd) + Century range (0-99, 100-199, etc.)
(define-public (get-hint (fee-amount uint))
    (let ((player tx-sender))
        ;; Validate fee
        (asserts! (>= fee-amount HINT-FEE) ERR-INSUFFICIENT-FEE)
        
        ;; Get active game
        (let ((game-opt (map-get? active-games player)))
            (asserts! (is-some game-opt) ERR-NO-ACTIVE-GAME)
            (let ((game (unwrap-panic game-opt)))
                ;; Check if hint already used
                (asserts! (not (get hint-used game)) ERR-HINT-ALREADY-USED)
                
                (let ((secret (get secret-number game))
                      (attempts (get attempts game))
                      (game-id (get game-id game)))
                    
                    ;; Calculate hint information
                    (let ((is-even (is-eq (mod secret u2) u0))
                          (century-start (* (/ secret u100) u100))
                          (century-end (+ century-start u99)))
                        
                        ;; Mark hint as used
                        (map-set active-games player {
                            secret-number: secret,
                            attempts: attempts,
                            hint-used: true,
                            game-id: game-id
                        })
                        
                        ;; STX fee is paid with transaction
                        (ok {
                            parity: (if is-even "even" "odd"),
                            range-start: century-start,
                            range-end: (if (> century-end MAX-NUMBER) MAX-NUMBER century-end),
                            message: "Hint revealed! The number is in this range and parity.",
                            fee-paid: HINT-FEE
                        })
                    )
                )
            )
        )
    )
)

;; Public function: Give up current game
(define-public (give-up)
    (let ((player tx-sender))
        ;; Get active game
        (let ((game-opt (map-get? active-games player)))
            (asserts! (is-some game-opt) ERR-NO-ACTIVE-GAME)
            (let ((game (unwrap-panic game-opt)))
                (let ((secret (get secret-number game))
                      (attempts (get attempts game))
                      (hint-used (get hint-used game)))
                    
                    ;; Remove active game
                    (map-delete active-games player)
                    
                    ;; Update stats (reset streak)
                    (let ((stats-opt (map-get? player-stats player)))
                        (match stats-opt stats-value
                            (map-set player-stats player {
                                total-games: (+ (get total-games stats-value) u1),
                                total-attempts: (+ (get total-attempts stats-value) attempts),
                                best-attempts: (get best-attempts stats-value),
                                current-streak: u0,  ;; Reset streak
                                longest-streak: (get longest-streak stats-value)
                            })
                            ;; First game and gave up
                            (map-set player-stats player {
                                total-games: u1,
                                total-attempts: attempts,
                                best-attempts: u0,
                                current-streak: u0,
                                longest-streak: u0
                            })
                        )
                    )
                    
                    ;; Save to history
                    (let ((player-game-id (default-to u0 (map-get? player-game-counter player))))
                        (map-set player-game-counter player (+ player-game-id u1))
                        (map-set game-history (tuple (player player) (game-id player-game-id)) {
                            secret-number: secret,
                            attempts: attempts,
                            won: false,
                            hint-used: hint-used
                        })
                    )
                    
                    (ok {
                        message: "Game over! The number was:",
                        secret-number: secret,
                        attempts-made: attempts
                    })
                )
            )
        )
    )
)

;; ============================================
;; Read-only functions for contract queries
;; ============================================

;; Read-only: Get active game state
(define-read-only (get-active-game (player principal))
    (map-get? active-games player)
)

;; Read-only: Get player statistics
(define-read-only (get-player-stats (player principal))
    (map-get? player-stats player)
)

;; Read-only: Get game history
(define-read-only (get-game-history (player principal) (game-id uint))
    (map-get? game-history (tuple (player player) (game-id game-id)))
)

;; Read-only: Get total games played
(define-read-only (get-total-games)
    (var-get total-games)
)

;; Read-only: Get total players
(define-read-only (get-player-count)
    (var-get player-count)
)

;; Read-only: Get player by index
(define-read-only (get-player-at-index (index uint))
    (map-get? player-list index)
)

;; Read-only: Get player game count
(define-read-only (get-player-game-count (player principal))
    (default-to u0 (map-get? player-game-counter player))
)

;; Read-only: Check if player has active game
(define-read-only (has-active-game (player principal))
    (is-some (map-get? active-games player))
)

;; Read-only: Get hint fee
(define-read-only (get-hint-fee)
    HINT-FEE
)

;; Read-only: Get game range
(define-read-only (get-game-range)
    {
        min: MIN-NUMBER,
        max: MAX-NUMBER
    }
)

;; Read-only: Get player with stats by index (for leaderboard)
(define-read-only (get-player-at-index-with-stats (index uint))
    (match (map-get? player-list index) address
        (let ((stats (map-get? player-stats address)))
            (match stats stats-value
                (some {
                    address: address,
                    total-games: (get total-games stats-value),
                    total-attempts: (get total-attempts stats-value),
                    best-attempts: (get best-attempts stats-value),
                    current-streak: (get current-streak stats-value),
                    longest-streak: (get longest-streak stats-value)
                })
                none
            )
        )
        none
    )
)
