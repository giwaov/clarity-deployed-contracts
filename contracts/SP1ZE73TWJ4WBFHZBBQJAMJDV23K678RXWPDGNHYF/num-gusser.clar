
;; title: num-gusser
;; version: 1.0.0
;; summary: A simple number guessing game
;; description: Players guess a number between 1 and 100 with limited attempts.

;; constants
(define-constant ERR_GAME_OVER (err u100))
(define-constant ERR_INVALID_GUESS (err u101))
(define-constant MAX_ATTEMPTS u10)

;; data vars
(define-data-var secret-number uint u0)
(define-data-var attempts-left uint u0)

;; public functions

(define-public (start-game)
    (begin
        ;; Generate a pseudo-random number based on block height
        ;; (mod burn-block-height 100) returns 0-99, so we add 1 to get 1-100
        (var-set secret-number (+ (mod burn-block-height u100) u1))
        (var-set attempts-left MAX_ATTEMPTS)
        (ok "Game started! Guess a number between 1 and 100.")
    )
)

(define-public (guess (user-guess uint))
    (let 
        (
            (current-attempts (var-get attempts-left))
            (secret (var-get secret-number))
        )
        (if (> current-attempts u0)
            (begin
                (var-set attempts-left (- current-attempts u1))
                (if (is-eq user-guess secret)
                    (ok "Correct! You win!")
                    (if (> user-guess secret)
                        (ok "Too High")
                        (ok "Too Low")
                    )
                )
            )
            ERR_GAME_OVER
        )
    )
)

;; read only functions

(define-read-only (get-state)
    (ok {
        attempts-left: (var-get attempts-left),
        ;; intended for debug/demo purposes only, usually wouldn't expose secret
        secret-debug: (var-get secret-number) 
    })
)
