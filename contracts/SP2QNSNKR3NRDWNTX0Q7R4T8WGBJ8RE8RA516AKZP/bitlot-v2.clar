
;; title: bitlot
;; summary: A simple lottery/spinner contract
;; description: Allows users to pay to spin and get a random result with token rewards.

;; constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_TRANSFER_FAILED (err u100))
(define-constant TICKET_PRICE u10000) ;; 0.01 STX (10,000 uSTX)

;; data vars
(define-data-var total-spins uint u0)

;; private functions
(define-private (get-reward-amount (result uint))
    (if (is-eq result u0) u0 ;; Loss
    (if (is-eq result u1) u10000000 ;; 10 tokens
    (if (is-eq result u2) u20000000 ;; 20 tokens
    (if (is-eq result u3) u50000000 ;; 50 tokens
    (if (is-eq result u4) u0 ;; Loss
    (if (is-eq result u5) u100000000 ;; 100 tokens
    (if (is-eq result u6) u200000000 ;; 200 tokens
    u500000000))))))) ;; 500 tokens (Jackpot)
)

;; public functions
(define-public (play)
    (let
        (
            (sender tx-sender)
            (current-spins (var-get total-spins))
            ;; Simple pseudo-randomness: hash of block-height + sender + nonce
            (random-source (sha256 (unwrap-panic (to-consensus-buff? { height: block-height, player: sender, nonce: current-spins }))))
            (random-val (buff-to-uint-be (unwrap-panic (element-at? random-source u0))))
            ;; Modulo 8 for 8 slots in the spinner
            (result (mod random-val u8))
            (reward (get-reward-amount result))
        )
        ;; Transfer STX from user to contract
        (try! (stx-transfer? TICKET_PRICE sender (as-contract tx-sender)))
        
        ;; Update state
        (var-set total-spins (+ current-spins u1))

        ;; Transfer Token Reward if > 0
        (if (> reward u0)
            (match (as-contract (contract-call? .bitlot-token transfer reward tx-sender sender none))
                success (begin
                    (print {
                        event: "spin-result",
                        player: sender,
                        result: result,
                        amount: TICKET_PRICE,
                        reward: reward
                    })
                    (ok result)
                )
                error (err error)
            )
            (begin
                (print {
                    event: "spin-result",
                    player: sender,
                    result: result,
                    amount: TICKET_PRICE,
                    reward: reward
                })
                (ok result)
            )
        )
    )
)

(define-read-only (get-total-spins)
    (ok (var-get total-spins))
)
