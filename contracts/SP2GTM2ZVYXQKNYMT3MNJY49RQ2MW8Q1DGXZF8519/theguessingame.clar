;; Guessing Game Contract

(define-constant GAME-OWNER tx-sender)
(define-constant GUESS-FEE u100000) ;; 0.1 STX to play
;; The hash of the number "42" (simplified for demo)
(define-constant SECRET-HASH 0x736563726574206e756d626572203432) 

(define-data-var jackpot uint u0)

;; Read the current jackpot size
(define-read-only (get-jackpot)
  (var-get jackpot)
)

;; Submit a guess
(define-public (guess (attempt uint))
  (begin
    ;; 1. Pay the entry fee to the jackpot
    (try! (stx-transfer? GUESS-FEE tx-sender (as-contract tx-sender)))
    (var-set jackpot (+ (var-get jackpot) GUESS-FEE))

    ;; 2. Check if the guess is 42 (The answer to life, the universe, and everything)
    (if (is-eq attempt u42)
        (let ((winnings (var-get jackpot)))
          (var-set jackpot u0)
          ;; Send the entire jackpot to the winner!
          (try! (as-contract (stx-transfer? winnings (as-contract tx-sender) tx-sender)))
          (ok "WINNER! You took the jackpot!"))
        (ok "Wrong guess. Your fee was added to the jackpot.")
    )
  )
)
