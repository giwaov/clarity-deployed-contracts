;; title: trivia-stx
;; version:
;; summary:
;; description:

;; Trivia Game Smart Contract

;; Error codes
(define-constant ERR-UNAUTHORIZED-ACCESS (err u100))
(define-constant ERR-TRIVIA-GAME-EXISTS (err u101))
(define-constant ERR-TRIVIA-GAME-NOT-FOUND (err u102))
(define-constant ERR-INVALID-STAKE-AMOUNT (err u103))
(define-constant ERR-TRIVIA-GAME-ENDED (err u104))
(define-constant ERR-DUPLICATE-ANSWER (err u105))
(define-constant ERR-INSUFFICIENT-STX-BALANCE (err u106))
(define-constant ERR-INVALID-INPUT (err u107))

;; Data variables
(define-data-var contract-administrator principal tx-sender)
(define-map trivia-game-records 
    uint 
    {
        game-creator: principal,
        trivia-question: (string-utf8 256),
        correct-answer: (string-utf8 256),
        total-prize-pool: uint,
        game-active-status: bool,
        winning-player: (optional principal)
    }
)

(define-map participant-submission-records
    { trivia-game-id: uint, participant-address: principal }
    { submitted-answer: (string-utf8 256), submission-timestamp: uint }
)

(define-data-var trivia-game-counter uint u0)

;; Helper functions
(define-private (is-valid-string (input (string-utf8 256)))
    (and (>= (len input) u1) (<= (len input) u256))
)

;; Read-only functions
(define-read-only (get-trivia-game-information (trivia-game-id uint))
    (match (map-get? trivia-game-records trivia-game-id)
        game-information (ok game-information)
        (err ERR-TRIVIA-GAME-NOT-FOUND)
    )
)

(define-read-only (get-participant-submission (trivia-game-id uint) (participant-address principal))
    (map-get? participant-submission-records 
        { trivia-game-id: trivia-game-id, participant-address: participant-address }
    )
)

(define-read-only (get-contract-administrator)
    (ok (var-get contract-administrator))
)

;; Admin functions
(define-public (transfer-contract-ownership (new-administrator principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-administrator)) (err ERR-UNAUTHORIZED-ACCESS))
        (asserts! (not (is-eq new-administrator (var-get contract-administrator))) (err ERR-INVALID-INPUT))
        (ok (var-set contract-administrator new-administrator))
    )
)
