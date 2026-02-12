;; Number Guess Pro Contract
;; Challenge mode - Exactly 10 attempts
;; Guess a number between 0-1000 within 10 tries
;; No fees, just gas - competitive gameplay
;; Optional hint available for 0.003 STX (consumes 1 attempt)

;; Error codes
(define-constant ERR-NO-ACTIVE-GAME (err u1001))
(define-constant ERR-GAME-ALREADY-ACTIVE (err u1002))
(define-constant ERR-INVALID-NUMBER (err u1003))
(define-constant ERR-INSUFFICIENT-FEE (err u1004))
(define-constant ERR-HINT-ALREADY-USED (err u1005))
(define-constant ERR-NO-ATTEMPTS-LEFT (err u1006))

;; Constants
(define-constant MIN-NUMBER u0)
(define-constant MAX-NUMBER u1000)
(define-constant MAX-ATTEMPTS u10)
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
    attempts-left: uint,
    attempts-used: uint,
    hint-used: bool,
    game-id: uint
})

;; Player statistics
(define-map player-stats principal {
    total-games: uint,
    wins: uint,
    total-score: uint,
    best-score: uint,
    perfect-games: uint  ;; Games won in 1 attempt
})

;; Game history: (player, game-id) -> {secret-number, attempts-used, won, score, hint-used}
(define-map game-history (tuple (player principal) (game-id uint)) {
    secret-number: uint,
    attempts-used: uint,
    won: bool,
    score: uint,
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

;; Helper to calculate score based on attempts
;; 1 attempt = 1000 points, 2 = 900, 3 = 800, ... 10 = 100
(define-private (calculate-score (attempts-used uint))
    (if (<= attempts-used MAX-ATTEMPTS)
        (- u1100 (* attempts-used u100))
        u0
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
                    attempts-left: MAX-ATTEMPTS,
                    attempts-used: u0,
                    hint-used: false,
                    game-id: game-counter
                })
                
                ;; Increment total games
                (var-set total-games (+ game-counter u1))
                
                (ok {
                    game-id: game-counter,
                    message: "Game started! 10 attempts",
                    min: MIN-NUMBER,
                    max: MAX-NUMBER,
                    attempts-left: MAX-ATTEMPTS
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
                      (attempts-left (get attempts-left game))
                      (attempts-used (get attempts-used game))
                      (game-id (get game-id game))
                      (hint-used (get hint-used game)))
                    
                    ;; Check if still has attempts
                    (asserts! (> attempts-left u0) ERR-NO-ATTEMPTS-LEFT)
                    
                    ;; Consume attempt
                    (let ((new-attempts-left (- attempts-left u1))
                          (new-attempts-used (+ attempts-used u1)))
                        
                        (if (is-eq number secret)
                            ;; Correct guess! End game with score
                            (let ((score (calculate-score new-attempts-used)))
                                ;; Remove active game
                                (map-delete active-games player)
                                
                                ;; Update stats
                                (let ((stats-opt (map-get? player-stats player)))
                                    (if (is-none stats-opt)
                                        ;; First game
                                        (map-set player-stats player {
                                            total-games: u1,
                                            wins: u1,
                                            total-score: score,
                                            best-score: score,
                                            perfect-games: (if (is-eq new-attempts-used u1) u1 u0)
                                        })
                                        ;; Update existing stats
                                        (let ((stats (unwrap-panic stats-opt)))
                                            (map-set player-stats player {
                                                total-games: (+ (get total-games stats) u1),
                                                wins: (+ (get wins stats) u1),
                                                total-score: (+ (get total-score stats) score),
                                                best-score: (if (> score (get best-score stats)) 
                                                              score 
                                                              (get best-score stats)),
                                                perfect-games: (+ (get perfect-games stats) 
                                                                 (if (is-eq new-attempts-used u1) u1 u0))
                                            })
                                        )
                                    )
                                )
                                
                                ;; Save to history
                                (let ((player-game-id (default-to u0 (map-get? player-game-counter player))))
                                    (map-set player-game-counter player (+ player-game-id u1))
                                    (map-set game-history (tuple (player player) (game-id player-game-id)) {
                                        secret-number: secret,
                                        attempts-used: new-attempts-used,
                                        won: true,
                                        score: score,
                                        hint-used: hint-used
                                    })
                                )
                                
                                (ok {
                                    result: "correct",
                                    attempts-used: new-attempts-used,
                                    score: score,
                                    message: "Victory!",
                                    hint-used: hint-used,
                                    number: (some secret)
                                })
                            )
                            ;; Wrong guess
                            (if (is-eq new-attempts-left u0)
                                ;; Game over - no more attempts
                                (begin
                                    ;; Remove active game
                                    (map-delete active-games player)
                                    
                                    ;; Update stats (loss)
                                    (let ((stats-opt (map-get? player-stats player)))
                                        (match stats-opt stats-value
                                            (map-set player-stats player {
                                                total-games: (+ (get total-games stats-value) u1),
                                                wins: (get wins stats-value),
                                                total-score: (get total-score stats-value),
                                                best-score: (get best-score stats-value),
                                                perfect-games: (get perfect-games stats-value)
                                            })
                                            (map-set player-stats player {
                                                total-games: u1,
                                                wins: u0,
                                                total-score: u0,
                                                best-score: u0,
                                                perfect-games: u0
                                            })
                                        )
                                    )
                                    
                                    ;; Save to history
                                    (let ((player-game-id (default-to u0 (map-get? player-game-counter player))))
                                        (map-set player-game-counter player (+ player-game-id u1))
                                        (map-set game-history (tuple (player player) (game-id player-game-id)) {
                                            secret-number: secret,
                                            attempts-used: new-attempts-used,
                                            won: false,
                                            score: u0,
                                            hint-used: hint-used
                                        })
                                    )
                                    
                                    (ok {
                                        result: "game-over",
                                        attempts-used: new-attempts-used,
                                        score: u0,
                                        message: "No attempts left!",
                                        hint-used: hint-used,
                                        number: (some secret)
                                    })
                                )
                                ;; Continue playing
                                (begin
                                    ;; Update game state
                                    (map-set active-games player {
                                        secret-number: secret,
                                        attempts-left: new-attempts-left,
                                        attempts-used: new-attempts-used,
                                        hint-used: hint-used,
                                        game-id: game-id
                                    })
                                    
                                    (ok {
                                        result: (if (> number secret) "lower" "higher"),
                                        attempts-used: new-attempts-used,
                                        score: u0,
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
)

;; Public function: Get hint (costs 0.003 STX, only 1 per game, consumes 1 attempt)
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
                
                ;; Check if still has attempts
                (let ((attempts-left (get attempts-left game)))
                    (asserts! (> attempts-left u0) ERR-NO-ATTEMPTS-LEFT)
                    
                    (let ((secret (get secret-number game))
                          (attempts-used (get attempts-used game))
                          (game-id (get game-id game)))
                        
                        ;; Consume 1 attempt for hint
                        (let ((new-attempts-left (- attempts-left u1))
                              (new-attempts-used (+ attempts-used u1)))
                            
                            ;; Calculate hint information
                            (let ((is-even (is-eq (mod secret u2) u0))
                                  (century-start (* (/ secret u100) u100))
                                  (century-end (+ century-start u99)))
                                
                                ;; Mark hint as used and consume attempt
                                (map-set active-games player {
                                    secret-number: secret,
                                    attempts-left: new-attempts-left,
                                    attempts-used: new-attempts-used,
                                    hint-used: true,
                                    game-id: game-id
                                })
                                
                                ;; STX fee is paid with transaction
                                (ok {
                                    parity: (if is-even "even" "odd"),
                                    range-start: century-start,
                                    range-end: (if (> century-end MAX-NUMBER) MAX-NUMBER century-end),
                                    message: "Hint revealed! 1 attempt used",
                                    attempts-left: new-attempts-left,
                                    fee-paid: HINT-FEE
                                })
                            )
                        )
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
                      (attempts-used (get attempts-used game))
                      (hint-used (get hint-used game)))
                    
                    ;; Remove active game
                    (map-delete active-games player)
                    
                    ;; Update stats (loss)
                    (let ((stats-opt (map-get? player-stats player)))
                        (match stats-opt stats-value
                            (map-set player-stats player {
                                total-games: (+ (get total-games stats-value) u1),
                                wins: (get wins stats-value),
                                total-score: (get total-score stats-value),
                                best-score: (get best-score stats-value),
                                perfect-games: (get perfect-games stats-value)
                            })
                            (map-set player-stats player {
                                total-games: u1,
                                wins: u0,
                                total-score: u0,
                                best-score: u0,
                                perfect-games: u0
                            })
                        )
                    )
                    
                    ;; Save to history
                    (let ((player-game-id (default-to u0 (map-get? player-game-counter player))))
                        (map-set player-game-counter player (+ player-game-id u1))
                        (map-set game-history (tuple (player player) (game-id player-game-id)) {
                            secret-number: secret,
                            attempts-used: attempts-used,
                            won: false,
                            score: u0,
                            hint-used: hint-used
                        })
                    )
                    
                    (ok {
                        message: "Game over! The number was:",
                        secret-number: secret,
                        attempts-used: attempts-used
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

;; Read-only: Get max attempts
(define-read-only (get-max-attempts)
    MAX-ATTEMPTS
)

;; Read-only: Get player with stats by index (for leaderboard)
(define-read-only (get-player-at-index-with-stats (index uint))
    (match (map-get? player-list index) address
        (let ((stats (map-get? player-stats address)))
            (match stats stats-value
                (some {
                    address: address,
                    total-games: (get total-games stats-value),
                    wins: (get wins stats-value),
                    total-score: (get total-score stats-value),
                    best-score: (get best-score stats-value),
                    perfect-games: (get perfect-games stats-value)
                })
                none
            )
        )
        none
    )
)

;; Read-only: Calculate win rate percentage (scaled by 100 for precision)
;; Returns win rate as percentage * 100 (e.g., 4500 = 45.00%)
(define-read-only (get-player-win-rate (player principal))
    (match (map-get? player-stats player) stats-value
        (let ((total (get total-games stats-value))
              (wins (get wins stats-value)))
            (if (is-eq total u0)
                u0
                (/ (* wins u10000) total)
            )
        )
        u0
    )
)

;; Read-only: Get average score per game
(define-read-only (get-player-average-score (player principal))
    (match (map-get? player-stats player) stats-value
        (let ((total (get total-games stats-value))
              (total-score (get total-score stats-value)))
            (if (is-eq total u0)
                u0
                (/ total-score total)
            )
        )
        u0
    )
)

;; Read-only: Check if player can use hint
(define-read-only (can-use-hint (player principal))
    (match (map-get? active-games player) game
        (and 
            (not (get hint-used game))
            (> (get attempts-left game) u0)
        )
        false
    )
)

;; Read-only: Get remaining attempts
(define-read-only (get-remaining-attempts (player principal))
    (match (map-get? active-games player) game
        (some (get attempts-left game))
        none
    )
)
