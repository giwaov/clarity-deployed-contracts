;; Wordle Game on Stacks
;; A decentralized Wordle game where players can guess daily words

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-already-played-today (err u101))
(define-constant err-invalid-guess-length (err u102))
(define-constant err-no-active-word (err u103))
(define-constant err-max-attempts-reached (err u104))
(define-constant err-invalid-word (err u105))

(define-constant max-attempts u6)
(define-constant word-length u5)

;; Data Variables
(define-data-var current-word-hash (buff 32) 0x0000000000000000000000000000000000000000000000000000000000000000)
(define-data-var current-day uint u0)
(define-data-var total-games-played uint u0)

;; Data Maps
;; Track player's game state for current day
(define-map player-games
    { player: principal, day: uint }
    {
        attempts: uint,
        guesses: (list 6 (string-ascii 5)),
        results: (list 6 (list 5 uint)), ;; 0=not present, 1=wrong position, 2=correct
        won: bool,
        completed: bool
    }
)

;; Track player stats
(define-map player-stats
    principal
    {
        games-played: uint,
        games-won: uint,
        current-streak: uint,
        max-streak: uint
    }
)

;; Valid word list (simplified - in production, use a larger list or merkle tree)
(define-map valid-words (string-ascii 5) bool)

;; Private Functions

;; Initialize some valid words (in production, this would be much larger)
(map-set valid-words "BLOCK" true)
(map-set valid-words "CHAIN" true)
(map-set valid-words "SMART" true)
(map-set valid-words "TOKEN" true)
(map-set valid-words "PIZZA" true)
(map-set valid-words "HELLO" true)
(map-set valid-words "WORLD" true)
(map-set valid-words "GUESS" true)
(map-set valid-words "PRIDE" true)
(map-set valid-words "CRANE" true)
(map-set valid-words "SLANT" true)
(map-set valid-words "TRACE" true)
(map-set valid-words "CRATE" true)
(map-set valid-words "SLATE" true)
(map-set valid-words "STACK" true)
(map-set valid-words "CLEAR" true)
(map-set valid-words "AUDIO" true)
(map-set valid-words "ROAST" true)
(map-set valid-words "PEACE" true)
(map-set valid-words "PLANT" true)

;; Check if a word is in the valid word list
(define-private (is-valid-word (word (string-ascii 5)))
    (default-to false (map-get? valid-words word))
)

;; Compare guess with the answer (simplified version)
;; Returns a list where: 0=not in word, 1=in word wrong position, 2=correct position
(define-private (check-guess (guess (string-ascii 5)) (answer-hash (buff 32)))
    ;; In a real implementation, this would need to compare against the actual word
    ;; For now, we'll return a placeholder that the frontend can verify
    ;; The hash ensures the word isn't revealed on-chain
    (list u0 u0 u0 u0 u0)
)

;; Read-only Functions

;; Get current game state for a player
(define-read-only (get-game-state (player principal))
    (map-get? player-games { player: player, day: (var-get current-day) })
)

;; Get player statistics
(define-read-only (get-player-stats (player principal))
    (default-to
        { games-played: u0, games-won: u0, current-streak: u0, max-streak: u0 }
        (map-get? player-stats player)
    )
)

;; Get current day
(define-read-only (get-current-day)
    (ok (var-get current-day))
)

;; Get total games played
(define-read-only (get-total-games)
    (ok (var-get total-games-played))
)

;; Check if player has played today
(define-read-only (has-played-today (player principal))
    (is-some (map-get? player-games { player: player, day: (var-get current-day) }))
)

;; Verify a guess against the word hash (for frontend validation)
(define-read-only (verify-word-hash (word (string-ascii 5)))
    (ok (sha256 (unwrap-panic (to-consensus-buff? word))))
)

;; Public Functions

;; Set new daily word (only contract owner can call)
(define-public (set-daily-word (word-hash (buff 32)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (var-set current-word-hash word-hash)
        (var-set current-day (+ (var-get current-day) u1))
        (ok true)
    )
)

;; Submit a guess
(define-public (submit-guess (guess (string-ascii 5)))
    (let
        (
            (player tx-sender)
            (day (var-get current-day))
            (word-hash (var-get current-word-hash))
            (game-state (get-game-state player))
        )
        ;; Validations
        (asserts! (> word-hash 0x0000000000000000000000000000000000000000000000000000000000000000) err-no-active-word)
        (asserts! (is-valid-word guess) err-invalid-word)
        
        ;; Check if player already has a game in progress
        (match game-state
            existing-game
            (begin
                ;; Check if game is already completed
                (asserts! (not (get completed existing-game)) err-already-played-today)
                ;; Check if max attempts reached
                (asserts! (< (get attempts existing-game) max-attempts) err-max-attempts-reached)
                
                ;; Add guess to existing game
                (let
                    (
                        (new-attempts (+ (get attempts existing-game) u1))
                        (guess-result (check-guess guess word-hash))
                        (is-correct (is-eq (sha256 (unwrap-panic (to-consensus-buff? guess))) word-hash))
                        (new-guesses (unwrap-panic (as-max-len? (append (get guesses existing-game) guess) u6)))
                        (new-results (unwrap-panic (as-max-len? (append (get results existing-game) guess-result) u6)))
                        (is-last-attempt (is-eq new-attempts max-attempts))
                        (game-ended (or is-correct is-last-attempt))
                    )
                    ;; Update game state
                    (map-set player-games
                        { player: player, day: day }
                        {
                            attempts: new-attempts,
                            guesses: new-guesses,
                            results: new-results,
                            won: is-correct,
                            completed: game-ended
                        }
                    )
                    
                    ;; Update player stats if game ended
                    (if game-ended
                        (update-player-stats player is-correct)
                        true
                    )
                    
                    (ok {
                        attempts: new-attempts,
                        is-correct: is-correct,
                        completed: game-ended,
                        won: is-correct
                    })
                )
            )
            ;; Start new game
            (let
                (
                    (guess-result (check-guess guess word-hash))
                    (is-correct (is-eq (sha256 (unwrap-panic (to-consensus-buff? guess))) word-hash))
                )
                (map-set player-games
                    { player: player, day: day }
                    {
                        attempts: u1,
                        guesses: (list guess),
                        results: (list guess-result),
                        won: is-correct,
                        completed: is-correct
                    }
                )
                
                ;; Update stats if game ended
                (if is-correct
                    (update-player-stats player true)
                    true
                )
                
                (ok {
                    attempts: u1,
                    is-correct: is-correct,
                    completed: is-correct,
                    won: is-correct
                })
            )
        )
    )
)

;; Update player statistics
(define-private (update-player-stats (player principal) (won bool))
    (let
        (
            (current-stats (get-player-stats player))
            (new-games-played (+ (get games-played current-stats) u1))
            (new-games-won (if won (+ (get games-won current-stats) u1) (get games-won current-stats)))
            (new-streak (if won (+ (get current-streak current-stats) u1) u0))
            (new-max-streak (if (> new-streak (get max-streak current-stats)) new-streak (get max-streak current-stats)))
        )
        (map-set player-stats player
            {
                games-played: new-games-played,
                games-won: new-games-won,
                current-streak: new-streak,
                max-streak: new-max-streak
            }
        )
        (var-set total-games-played (+ (var-get total-games-played) u1))
        true
    )
)

;; Admin function to add valid words
(define-public (add-valid-word (word (string-ascii 5)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-authorized)
        (ok (map-set valid-words word true))
    )
)
