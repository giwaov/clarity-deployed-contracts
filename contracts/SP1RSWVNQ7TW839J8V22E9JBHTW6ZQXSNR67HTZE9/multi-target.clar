;; Multi-Target Contract
;; Guess multiple hidden numbers that sum to a known total
;; Example: Find 3 numbers (0-100) that sum to 150
;; High difficulty - massive search space
;; No fees, just gas - pure deduction gameplay

;; Error codes
(define-constant ERR-NO-ACTIVE-GAME (err u1001))
(define-constant ERR-GAME-ALREADY-ACTIVE (err u1002))
(define-constant ERR-INVALID-GUESS (err u1003))
(define-constant ERR-WRONG-COUNT (err u1004))
(define-constant ERR-NO-ATTEMPTS-LEFT (err u1005))

;; Constants
(define-constant TARGET-COUNT u3)  ;; 3 numbers to guess
(define-constant MIN-NUMBER u0)
(define-constant MAX-NUMBER u100)
(define-constant MAX-ATTEMPTS u15)  ;; More attempts due to difficulty

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
    targets: (list 3 uint),      ;; The 3 secret numbers
    target-sum: uint,             ;; Known sum (the clue!)
    attempts-left: uint,
    attempts-used: uint,
    game-id: uint
})

;; Attempt history: (player, attempt-num) -> {guess, exact-matches}
(define-map attempt-history (tuple (player principal) (attempt-num uint)) {
    guess: (list 3 uint),
    exact-matches: uint  ;; How many numbers are exactly right (value + position)
})

;; Player statistics
(define-map player-stats principal {
    total-games: uint,
    wins: uint,
    best-attempts: uint
})

;; Game history: (player, game-id) -> {targets, attempts-used, won}
(define-map game-history (tuple (player principal) (game-id uint)) {
    targets: (list 3 uint),
    target-sum: uint,
    attempts-used: uint,
    won: bool
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

;; Helper to generate 3 random numbers
(define-private (generate-targets (seed uint))
    (let ((base-seed (+ (+ (* seed u997) stacks-block-height) (var-get player-count))))
        (list
            (+ MIN-NUMBER (mod base-seed (+ u1 (- MAX-NUMBER MIN-NUMBER))))
            (+ MIN-NUMBER (mod (+ base-seed u37) (+ u1 (- MAX-NUMBER MIN-NUMBER))))
            (+ MIN-NUMBER (mod (+ base-seed u73) (+ u1 (- MAX-NUMBER MIN-NUMBER))))
        )
    )
)

;; Helper to calculate sum of list
(define-private (sum-list (numbers (list 3 uint)))
    (+ (unwrap-panic (element-at? numbers u0))
       (unwrap-panic (element-at? numbers u1))
       (unwrap-panic (element-at? numbers u2)))
)

;; Helper to validate guess
(define-private (validate-guess (user-numbers (list 3 uint)))
    (and
        (is-eq (len user-numbers) TARGET-COUNT)
        (<= (unwrap-panic (element-at? user-numbers u0)) MAX-NUMBER)
        (<= (unwrap-panic (element-at? user-numbers u1)) MAX-NUMBER)
        (<= (unwrap-panic (element-at? user-numbers u2)) MAX-NUMBER)
    )
)

;; Public function: Start new game
(define-public (start-game)
    (let ((player tx-sender))
        (asserts! (is-none (map-get? active-games player)) ERR-GAME-ALREADY-ACTIVE)
        (add-player-if-new player)
        
        (let ((game-counter (var-get total-games)))
            (let ((targets (generate-targets game-counter))
                  (target-sum (sum-list targets)))
                (map-set active-games player {
                    targets: targets,
                    target-sum: target-sum,
                    attempts-left: MAX-ATTEMPTS,
                    attempts-used: u0,
                    game-id: game-counter
                })
                (var-set total-games (+ game-counter u1))
                (ok {
                    game-id: game-counter,
                    message: "Find 3 numbers that sum to:",
                    target-sum: target-sum,
                    range: "0-100",
                    attempts-left: MAX-ATTEMPTS
                })
            )
        )
    )
)

;; Helper to count exact matches (right number, right position)
(define-private (count-exact-matches (user-guess (list 3 uint)) (targets (list 3 uint)))
    (+ (if (is-eq (unwrap-panic (element-at? user-guess u0)) (unwrap-panic (element-at? targets u0))) u1 u0)
       (if (is-eq (unwrap-panic (element-at? user-guess u1)) (unwrap-panic (element-at? targets u1))) u1 u0)
       (if (is-eq (unwrap-panic (element-at? user-guess u2)) (unwrap-panic (element-at? targets u2))) u1 u0))
)

;; Public function: Make a guess
(define-public (guess (numbers (list 3 uint)))
    (let ((player tx-sender))
        (asserts! (validate-guess numbers) ERR-INVALID-GUESS)
        (let ((game-opt (map-get? active-games player)))
            (asserts! (is-some game-opt) ERR-NO-ACTIVE-GAME)
            (let ((game (unwrap-panic game-opt)))
                (let ((targets (get targets game))
                      (target-sum (get target-sum game))
                      (attempts-left (get attempts-left game))
                      (attempts-used (get attempts-used game))
                      (game-id (get game-id game)))
                    (asserts! (> attempts-left u0) ERR-NO-ATTEMPTS-LEFT)
                    (let ((guess-sum (sum-list numbers))
                          (exact-matches (count-exact-matches numbers targets))
                          (new-attempts-left (- attempts-left u1))
                          (new-attempts-used (+ attempts-used u1)))
                        (map-set attempt-history (tuple (player player) (attempt-num attempts-used)) {
                            guess: numbers,
                            exact-matches: exact-matches
                        })
                        (if (is-eq exact-matches TARGET-COUNT)
                            ;; Victory!
                            (begin
                                (map-delete active-games player)
                                (let ((stats-opt (map-get? player-stats player)))
                                    (if (is-none stats-opt)
                                        (map-set player-stats player {total-games: u1, wins: u1, best-attempts: new-attempts-used})
                                        (let ((stats (unwrap-panic stats-opt)))
                                            (map-set player-stats player {
                                                total-games: (+ (get total-games stats) u1),
                                                wins: (+ (get wins stats) u1),
                                                best-attempts: (if (< new-attempts-used (get best-attempts stats)) new-attempts-used (get best-attempts stats))
                                            })
                                        )
                                    )
                                )
                                (let ((player-game-id (default-to u0 (map-get? player-game-counter player))))
                                    (map-set player-game-counter player (+ player-game-id u1))
                                    (map-set game-history (tuple (player player) (game-id player-game-id)) {
                                        targets: targets,
                                        target-sum: target-sum,
                                        attempts-used: new-attempts-used,
                                        won: true
                                    })
                                )
                                (ok {result: "victory", exact-matches: exact-matches, guess-sum: guess-sum, target-sum: target-sum, attempts-used: new-attempts-used, targets: (some targets)})
                            )
                            (if (is-eq new-attempts-left u0)
                                ;; Game over
                                (begin
                                    (map-delete active-games player)
                                    (let ((stats-opt (map-get? player-stats player)))
                                        (match stats-opt stats-value
                                            (map-set player-stats player {total-games: (+ (get total-games stats-value) u1), wins: (get wins stats-value), best-attempts: (get best-attempts stats-value)})
                                            (map-set player-stats player {total-games: u1, wins: u0, best-attempts: u0})
                                        )
                                    )
                                    (let ((player-game-id (default-to u0 (map-get? player-game-counter player))))
                                        (map-set player-game-counter player (+ player-game-id u1))
                                        (map-set game-history (tuple (player player) (game-id player-game-id)) {targets: targets, target-sum: target-sum, attempts-used: new-attempts-used, won: false})
                                    )
                                    (ok {result: "game-over", exact-matches: exact-matches, guess-sum: guess-sum, target-sum: target-sum, attempts-used: new-attempts-used, targets: (some targets)})
                                )
                                ;; Continue
                                (begin
                                    (map-set active-games player {targets: targets, target-sum: target-sum, attempts-left: new-attempts-left, attempts-used: new-attempts-used, game-id: game-id})
                                    (ok {result: "continue", exact-matches: exact-matches, guess-sum: guess-sum, target-sum: target-sum, attempts-used: new-attempts-used, targets: none})
                                )
                            )
                        )
                    )
                )
            )
        )
    )
)

;; Public function: Give up
(define-public (give-up)
    (let ((player tx-sender))
        (let ((game-opt (map-get? active-games player)))
            (asserts! (is-some game-opt) ERR-NO-ACTIVE-GAME)
            (let ((game (unwrap-panic game-opt)))
                (let ((targets (get targets game))
                      (target-sum (get target-sum game))
                      (attempts-used (get attempts-used game)))
                    (map-delete active-games player)
                    (let ((stats-opt (map-get? player-stats player)))
                        (match stats-opt stats-value
                            (map-set player-stats player {total-games: (+ (get total-games stats-value) u1), wins: (get wins stats-value), best-attempts: (get best-attempts stats-value)})
                            (map-set player-stats player {total-games: u1, wins: u0, best-attempts: u0})
                        )
                    )
                    (let ((player-game-id (default-to u0 (map-get? player-game-counter player))))
                        (map-set player-game-counter player (+ player-game-id u1))
                        (map-set game-history (tuple (player player) (game-id player-game-id)) {targets: targets, target-sum: target-sum, attempts-used: attempts-used, won: false})
                    )
                    (ok {message: "Targets were:", targets: targets, target-sum: target-sum})
                )
            )
        )
    )
)

;; Read-only functions
(define-read-only (get-active-game (player principal))
    (match (map-get? active-games player) game
        (some {target-sum: (get target-sum game), attempts-left: (get attempts-left game), attempts-used: (get attempts-used game)})
        none
    )
)

(define-read-only (get-player-stats (player principal))
    (map-get? player-stats player)
)

(define-read-only (get-attempt (player principal) (attempt-num uint))
    (map-get? attempt-history (tuple (player player) (attempt-num attempt-num)))
)

(define-read-only (has-active-game (player principal))
    (is-some (map-get? active-games player))
)

(define-read-only (get-total-games)
    (var-get total-games)
)

(define-read-only (get-player-count)
    (var-get player-count)
)

(define-read-only (get-game-info)
    {target-count: TARGET-COUNT, min-number: MIN-NUMBER, max-number: MAX-NUMBER, max-attempts: MAX-ATTEMPTS}
)
