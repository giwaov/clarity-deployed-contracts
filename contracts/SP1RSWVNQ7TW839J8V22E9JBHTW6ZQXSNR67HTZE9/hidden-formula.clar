;; Hidden Formula Contract
;; Discover the secret mathematical formula by testing inputs
;; You send numbers, get results, deduce the formula
;; Examples: f(x) = x^2 + 3, f(x) = 2x - 5, etc.
;; No fees, just gas - scientific deduction gameplay

;; Error codes
(define-constant ERR-NO-ACTIVE-GAME (err u1001))
(define-constant ERR-GAME-ALREADY-ACTIVE (err u1002))
(define-constant ERR-INVALID-INPUT (err u1003))
(define-constant ERR-NO-ATTEMPTS-LEFT (err u1004))

;; Constants
(define-constant MAX-INPUT u20)
(define-constant MAX-ATTEMPTS u12)

;; Formula types (coefficients stored as: a, b, c for ax^2 + bx + c)
(define-data-var total-games uint u0)
(define-data-var player-count uint u0)

(define-map player-list uint principal)
(define-map player-index principal (optional uint))

;; Game state: formula is ax^2 + bx + c
(define-map active-games principal {
    coef-a: uint,
    coef-b: uint,
    coef-c: uint,
    attempts-left: uint,
    attempts-used: uint,
    game-id: uint,
    solved: bool
})

;; Test history: (player, test-num) -> {input, output}
(define-map test-history (tuple (player principal) (test-num uint)) {
    input: uint,
    output: uint
})

(define-map player-stats principal {
    total-games: uint,
    wins: uint,
    best-attempts: uint
})

(define-map game-history (tuple (player principal) (game-id uint)) {
    formula: (tuple (a uint) (b uint) (c uint)),
    attempts-used: uint,
    won: bool
})

(define-map player-game-counter principal uint)

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

;; Generate formula: ax^2 + bx + c where a in [0,3], b in [0,5], c in [0,10]
(define-private (generate-formula (seed uint))
    (let ((base (+ (+ (* seed u997) stacks-block-height) (var-get player-count))))
        {
            a: (mod base u4),              ;; 0-3
            b: (mod (+ base u17) u6),      ;; 0-5
            c: (mod (+ base u37) u11)      ;; 0-10
        }
    )
)

;; Calculate f(x) = ax^2 + bx + c
(define-private (apply-formula (x uint) (a uint) (b uint) (c uint))
    (+ (* a (* x x)) (+ (* b x) c))
)

(define-public (start-game)
    (let ((player tx-sender))
        (asserts! (is-none (map-get? active-games player)) ERR-GAME-ALREADY-ACTIVE)
        (add-player-if-new player)
        (let ((game-counter (var-get total-games)))
            (let ((formula (generate-formula game-counter)))
                (map-set active-games player {
                    coef-a: (get a formula),
                    coef-b: (get b formula),
                    coef-c: (get c formula),
                    attempts-left: MAX-ATTEMPTS,
                    attempts-used: u0,
                    game-id: game-counter,
                    solved: false
                })
                (var-set total-games (+ game-counter u1))
                (ok {
                    game-id: game-counter,
                    message: "Discover the formula: f(x) = ax^2 + bx + c",
                    hints: "a: 0-3, b: 0-5, c: 0-10",
                    attempts-left: MAX-ATTEMPTS
                })
            )
        )
    )
)

;; Test a number to see the output
(define-public (test-input (x uint))
    (let ((player tx-sender))
        (asserts! (<= x MAX-INPUT) ERR-INVALID-INPUT)
        (let ((game-opt (map-get? active-games player)))
            (asserts! (is-some game-opt) ERR-NO-ACTIVE-GAME)
            (let ((game (unwrap-panic game-opt)))
                (let ((a (get coef-a game))
                      (b (get coef-b game))
                      (c (get coef-c game))
                      (attempts-left (get attempts-left game))
                      (attempts-used (get attempts-used game))
                      (game-id (get game-id game)))
                    (asserts! (> attempts-left u0) ERR-NO-ATTEMPTS-LEFT)
                    (let ((output (apply-formula x a b c))
                          (new-attempts-left (- attempts-left u1))
                          (new-attempts-used (+ attempts-used u1)))
                        (map-set test-history (tuple (player player) (test-num attempts-used)) {
                            input: x,
                            output: output
                        })
                        (map-set active-games player {
                            coef-a: a, coef-b: b, coef-c: c,
                            attempts-left: new-attempts-left,
                            attempts-used: new-attempts-used,
                            game-id: game-id,
                            solved: (get solved game)
                        })
                        (ok {input: x, output: output, attempts-left: new-attempts-left})
                    )
                )
            )
        )
    )
)

;; Submit formula guess
(define-public (submit-formula (guess-a uint) (guess-b uint) (guess-c uint))
    (let ((player tx-sender))
        (let ((game-opt (map-get? active-games player)))
            (asserts! (is-some game-opt) ERR-NO-ACTIVE-GAME)
            (let ((game (unwrap-panic game-opt)))
                (let ((a (get coef-a game))
                      (b (get coef-b game))
                      (c (get coef-c game))
                      (attempts-used (get attempts-used game)))
                    (if (and (is-eq guess-a a) (and (is-eq guess-b b) (is-eq guess-c c)))
                        (begin
                            (map-delete active-games player)
                            (let ((stats-opt (map-get? player-stats player)))
                                (if (is-none stats-opt)
                                    (map-set player-stats player {total-games: u1, wins: u1, best-attempts: attempts-used})
                                    (let ((stats (unwrap-panic stats-opt)))
                                        (map-set player-stats player {
                                            total-games: (+ (get total-games stats) u1),
                                            wins: (+ (get wins stats) u1),
                                            best-attempts: (if (< attempts-used (get best-attempts stats)) attempts-used (get best-attempts stats))
                                        })
                                    )
                                )
                            )
                            (let ((player-game-id (default-to u0 (map-get? player-game-counter player))))
                                (map-set player-game-counter player (+ player-game-id u1))
                                (map-set game-history (tuple (player player) (game-id player-game-id)) {
                                    formula: (tuple (a a) (b b) (c c)),
                                    attempts-used: attempts-used,
                                    won: true
                                })
                            )
                            (ok {result: "victory", formula: (some (tuple (a a) (b b) (c c))), attempts-used: attempts-used, message: "Correct!"})
                        )
                        (ok {result: "incorrect", formula: none, attempts-used: attempts-used, message: "Not the right formula"})
                    )
                )
            )
        )
    )
)

(define-public (give-up)
    (let ((player tx-sender))
        (let ((game-opt (map-get? active-games player)))
            (asserts! (is-some game-opt) ERR-NO-ACTIVE-GAME)
            (let ((game (unwrap-panic game-opt)))
                (let ((a (get coef-a game))
                      (b (get coef-b game))
                      (c (get coef-c game))
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
                        (map-set game-history (tuple (player player) (game-id player-game-id)) {
                            formula: (tuple (a a) (b b) (c c)),
                            attempts-used: attempts-used,
                            won: false
                        })
                    )
                    (ok {message: "Formula was:", a: a, b: b, c: c})
                )
            )
        )
    )
)

;; Read-only functions
(define-read-only (get-active-game (player principal))
    (match (map-get? active-games player) game
        (some {attempts-left: (get attempts-left game), attempts-used: (get attempts-used game)})
        none
    )
)

(define-read-only (get-player-stats (player principal))
    (map-get? player-stats player)
)

(define-read-only (get-test (player principal) (test-num uint))
    (map-get? test-history (tuple (player player) (test-num test-num)))
)

(define-read-only (has-active-game (player principal))
    (is-some (map-get? active-games player))
)

(define-read-only (get-total-games)
    (var-get total-games)
)

(define-read-only (get-game-info)
    {max-input: MAX-INPUT, max-attempts: MAX-ATTEMPTS}
)
