;; Mastermind Contract
;; Classic code-breaking game on-chain
;; Guess the secret 5-digit code (0-9)
;; 10 attempts to crack the code
;; Feedback: exact matches and number matches with wrong position
;; No fees, just gas - pure deduction gameplay

;; Error codes
(define-constant ERR-NO-ACTIVE-GAME (err u1001))
(define-constant ERR-GAME-ALREADY-ACTIVE (err u1002))
(define-constant ERR-INVALID-CODE (err u1003))
(define-constant ERR-INVALID-CODE-LENGTH (err u1004))
(define-constant ERR-NO-ATTEMPTS-LEFT (err u1005))

;; Constants
(define-constant CODE-LENGTH u5)
(define-constant MAX-DIGIT u9)
(define-constant MAX-ATTEMPTS u10)

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
    secret-code: (list 5 uint),
    attempts-left: uint,
    attempts-used: uint,
    game-id: uint
})

;; Attempt history per game: (player, attempt-number) -> {code, exact, partial}
(define-map attempt-history (tuple (player principal) (attempt-num uint)) {
    code: (list 5 uint),
    exact-matches: uint,
    partial-matches: uint
})

;; Player statistics
(define-map player-stats principal {
    total-games: uint,
    wins: uint,
    total-attempts: uint,
    best-attempts: uint,  ;; Fewest attempts to win
    perfect-games: uint   ;; Games won in 1 attempt (lucky!)
})

;; Game history: (player, game-id) -> {secret-code, attempts-used, won, score}
(define-map game-history (tuple (player principal) (game-id uint)) {
    secret-code: (list 5 uint),
    attempts-used: uint,
    won: bool,
    score: uint
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

;; Helper to generate random code
(define-private (generate-secret-code (seed uint))
    (let ((base-seed (+ (+ (* seed u997) stacks-block-height) (var-get player-count))))
        (list
            (mod base-seed u10)
            (mod (+ base-seed u13) u10)
            (mod (+ base-seed u37) u10)
            (mod (+ base-seed u71) u10)
            (mod (+ base-seed u113) u10)
        )
    )
)

;; Helper to validate code format
(define-private (validate-code (code (list 5 uint)))
    (let ((code-len (len code)))
        (and
            (is-eq code-len CODE-LENGTH)
            (<= (unwrap-panic (element-at? code u0)) MAX-DIGIT)
            (<= (unwrap-panic (element-at? code u1)) MAX-DIGIT)
            (<= (unwrap-panic (element-at? code u2)) MAX-DIGIT)
            (<= (unwrap-panic (element-at? code u3)) MAX-DIGIT)
            (<= (unwrap-panic (element-at? code u4)) MAX-DIGIT)
        )
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
            ;; Generate secret code
            (let ((secret (generate-secret-code game-counter)))
                ;; Create new game
                (map-set active-games player {
                    secret-code: secret,
                    attempts-left: MAX-ATTEMPTS,
                    attempts-used: u0,
                    game-id: game-counter
                })
                
                ;; Increment total games
                (var-set total-games (+ game-counter u1))
                
                (ok {
                    game-id: game-counter,
                    message: "Crack the 5-digit code!",
                    digits-range: "0-9",
                    attempts-left: MAX-ATTEMPTS
                })
            )
        )
    )
)

;; Helper to count exact matches (right digit, right position)
(define-private (count-exact-matches (user-code (list 5 uint)) (secret (list 5 uint)))
    (let ((matches
        (+ (if (is-eq (unwrap-panic (element-at? user-code u0)) (unwrap-panic (element-at? secret u0))) u1 u0)
           (if (is-eq (unwrap-panic (element-at? user-code u1)) (unwrap-panic (element-at? secret u1))) u1 u0)
           (if (is-eq (unwrap-panic (element-at? user-code u2)) (unwrap-panic (element-at? secret u2))) u1 u0)
           (if (is-eq (unwrap-panic (element-at? user-code u3)) (unwrap-panic (element-at? secret u3))) u1 u0)
           (if (is-eq (unwrap-panic (element-at? user-code u4)) (unwrap-panic (element-at? secret u4))) u1 u0))))
        matches
    )
)

;; Helper to count occurrences of a digit in code
(define-private (count-digit-in-code (digit uint) (code (list 5 uint)))
    (+ (if (is-eq (unwrap-panic (element-at? code u0)) digit) u1 u0)
       (if (is-eq (unwrap-panic (element-at? code u1)) digit) u1 u0)
       (if (is-eq (unwrap-panic (element-at? code u2)) digit) u1 u0)
       (if (is-eq (unwrap-panic (element-at? code u3)) digit) u1 u0)
       (if (is-eq (unwrap-panic (element-at? code u4)) digit) u1 u0))
)

;; Helper min function
(define-private (min (a uint) (b uint))
    (if (< a b) a b)
)

;; Helper to count total matches (including wrong positions)
(define-private (count-total-matches (user-code (list 5 uint)) (secret (list 5 uint)))
    (let ((d0 (min (count-digit-in-code u0 user-code) (count-digit-in-code u0 secret)))
          (d1 (min (count-digit-in-code u1 user-code) (count-digit-in-code u1 secret)))
          (d2 (min (count-digit-in-code u2 user-code) (count-digit-in-code u2 secret)))
          (d3 (min (count-digit-in-code u3 user-code) (count-digit-in-code u3 secret)))
          (d4 (min (count-digit-in-code u4 user-code) (count-digit-in-code u4 secret)))
          (d5 (min (count-digit-in-code u5 user-code) (count-digit-in-code u5 secret)))
          (d6 (min (count-digit-in-code u6 user-code) (count-digit-in-code u6 secret)))
          (d7 (min (count-digit-in-code u7 user-code) (count-digit-in-code u7 secret)))
          (d8 (min (count-digit-in-code u8 user-code) (count-digit-in-code u8 secret)))
          (d9 (min (count-digit-in-code u9 user-code) (count-digit-in-code u9 secret))))
        (+ d0 d1 d2 d3 d4 d5 d6 d7 d8 d9)
    )
)

;; Helper to calculate partial matches (right digit, wrong position)
(define-private (calculate-feedback (user-code (list 5 uint)) (secret (list 5 uint)))
    (let ((exact (count-exact-matches user-code secret))
          (total (count-total-matches user-code secret)))
        {
            exact: exact,
            partial: (- total exact)
        }
    )
)

;; Public function: Make a guess
(define-public (guess (code (list 5 uint)))
    (let ((player tx-sender))
        ;; Validate code format
        (asserts! (validate-code code) ERR-INVALID-CODE)
        
        ;; Get active game
        (let ((game-opt (map-get? active-games player)))
            (asserts! (is-some game-opt) ERR-NO-ACTIVE-GAME)
            (let ((game (unwrap-panic game-opt)))
                (let ((secret (get secret-code game))
                      (attempts-left (get attempts-left game))
                      (attempts-used (get attempts-used game))
                      (game-id (get game-id game)))
                    
                    ;; Check if still has attempts
                    (asserts! (> attempts-left u0) ERR-NO-ATTEMPTS-LEFT)
                    
                    ;; Calculate feedback
                    (let ((feedback (calculate-feedback code secret))
                          (exact (get exact feedback))
                          (partial (get partial feedback))
                          (new-attempts-left (- attempts-left u1))
                          (new-attempts-used (+ attempts-used u1)))
                        
                        ;; Store attempt in history
                        (map-set attempt-history (tuple (player player) (attempt-num attempts-used)) {
                            code: code,
                            exact-matches: exact,
                            partial-matches: partial
                        })
                        
                        ;; Check if won
                        (if (is-eq exact CODE-LENGTH)
                            ;; Victory!
                            (let ((score (- u1100 (* new-attempts-used u100))))
                                ;; Remove active game
                                (map-delete active-games player)
                                
                                ;; Update stats
                                (let ((stats-opt (map-get? player-stats player)))
                                    (if (is-none stats-opt)
                                        (map-set player-stats player {
                                            total-games: u1,
                                            wins: u1,
                                            total-attempts: new-attempts-used,
                                            best-attempts: new-attempts-used,
                                            perfect-games: (if (is-eq new-attempts-used u1) u1 u0)
                                        })
                                        (let ((stats (unwrap-panic stats-opt)))
                                            (map-set player-stats player {
                                                total-games: (+ (get total-games stats) u1),
                                                wins: (+ (get wins stats) u1),
                                                total-attempts: (+ (get total-attempts stats) new-attempts-used),
                                                best-attempts: (if (< new-attempts-used (get best-attempts stats))
                                                                  new-attempts-used
                                                                  (get best-attempts stats)),
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
                                        secret-code: secret,
                                        attempts-used: new-attempts-used,
                                        won: true,
                                        score: score
                                    })
                                )
                                
                                (ok {
                                    result: "victory",
                                    exact-matches: exact,
                                    partial-matches: partial,
                                    attempts-used: new-attempts-used,
                                    score: score,
                                    secret-code: (some secret)
                                })
                            )
                            ;; Not yet won
                            (if (is-eq new-attempts-left u0)
                                ;; Game over - no more attempts
                                (begin
                                    (map-delete active-games player)
                                    
                                    ;; Update stats (loss)
                                    (let ((stats-opt (map-get? player-stats player)))
                                        (match stats-opt stats-value
                                            (map-set player-stats player {
                                                total-games: (+ (get total-games stats-value) u1),
                                                wins: (get wins stats-value),
                                                total-attempts: (+ (get total-attempts stats-value) new-attempts-used),
                                                best-attempts: (get best-attempts stats-value),
                                                perfect-games: (get perfect-games stats-value)
                                            })
                                            (map-set player-stats player {
                                                total-games: u1,
                                                wins: u0,
                                                total-attempts: new-attempts-used,
                                                best-attempts: u0,
                                                perfect-games: u0
                                            })
                                        )
                                    )
                                    
                                    ;; Save to history
                                    (let ((player-game-id (default-to u0 (map-get? player-game-counter player))))
                                        (map-set player-game-counter player (+ player-game-id u1))
                                        (map-set game-history (tuple (player player) (game-id player-game-id)) {
                                            secret-code: secret,
                                            attempts-used: new-attempts-used,
                                            won: false,
                                            score: u0
                                        })
                                    )
                                    
                                    (ok {
                                        result: "game-over",
                                        exact-matches: exact,
                                        partial-matches: partial,
                                        attempts-used: new-attempts-used,
                                        score: u0,
                                        secret-code: (some secret)
                                    })
                                )
                                ;; Continue playing
                                (begin
                                    (map-set active-games player {
                                        secret-code: secret,
                                        attempts-left: new-attempts-left,
                                        attempts-used: new-attempts-used,
                                        game-id: game-id
                                    })
                                    
                                    (ok {
                                        result: "continue",
                                        exact-matches: exact,
                                        partial-matches: partial,
                                        attempts-used: new-attempts-used,
                                        score: u0,
                                        secret-code: none
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

;; ============================================
;; Read-only functions for contract queries
;; ============================================

;; Read-only: Get active game state (without secret code!)
(define-read-only (get-active-game (player principal))
    (match (map-get? active-games player) game
        (some {
            attempts-left: (get attempts-left game),
            attempts-used: (get attempts-used game),
            game-id: (get game-id game)
        })
        none
    )
)

;; Read-only: Get player statistics
(define-read-only (get-player-stats (player principal))
    (map-get? player-stats player)
)

;; Read-only: Get attempt history
(define-read-only (get-attempt (player principal) (attempt-num uint))
    (map-get? attempt-history (tuple (player player) (attempt-num attempt-num)))
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

;; Read-only: Get game constants
(define-read-only (get-game-info)
    {
        code-length: CODE-LENGTH,
        max-digit: MAX-DIGIT,
        max-attempts: MAX-ATTEMPTS
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
                    wins: (get wins stats-value),
                    total-attempts: (get total-attempts stats-value),
                    best-attempts: (get best-attempts stats-value),
                    perfect-games: (get perfect-games stats-value)
                })
                none
            )
        )
        none
    )
)

;; Read-only: Calculate win rate
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

;; Read-only: Get average attempts per win
(define-read-only (get-player-avg-attempts (player principal))
    (match (map-get? player-stats player) stats-value
        (let ((wins (get wins stats-value))
              (total-attempts (get total-attempts stats-value)))
            (if (is-eq wins u0)
                u0
                (/ total-attempts wins)
            )
        )
        u0
    )
)

;; Public function: Give up current game
(define-public (give-up)
    (let ((player tx-sender))
        ;; Get active game
        (let ((game-opt (map-get? active-games player)))
            (asserts! (is-some game-opt) ERR-NO-ACTIVE-GAME)
            (let ((game (unwrap-panic game-opt)))
                (let ((secret (get secret-code game))
                      (attempts-used (get attempts-used game)))
                    
                    ;; Remove active game
                    (map-delete active-games player)
                    
                    ;; Update stats (loss)
                    (let ((stats-opt (map-get? player-stats player)))
                        (match stats-opt stats-value
                            (map-set player-stats player {
                                total-games: (+ (get total-games stats-value) u1),
                                wins: (get wins stats-value),
                                total-attempts: (+ (get total-attempts stats-value) attempts-used),
                                best-attempts: (get best-attempts stats-value),
                                perfect-games: (get perfect-games stats-value)
                            })
                            (map-set player-stats player {
                                total-games: u1,
                                wins: u0,
                                total-attempts: attempts-used,
                                best-attempts: u0,
                                perfect-games: u0
                            })
                        )
                    )
                    
                    ;; Save to history
                    (let ((player-game-id (default-to u0 (map-get? player-game-counter player))))
                        (map-set player-game-counter player (+ player-game-id u1))
                        (map-set game-history (tuple (player player) (game-id player-game-id)) {
                            secret-code: secret,
                            attempts-used: attempts-used,
                            won: false,
                            score: u0
                        })
                    )
                    
                    (ok {
                        message: "Game over! The secret code was:",
                        secret-code: secret,
                        attempts-used: attempts-used
                    })
                )
            )
        )
    )
)
