;; Bitcoin Daily Lottery Contract
;; A provably fair lottery using Bitcoin block hashes for randomness

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_LOTTERY_NOT_ACTIVE (err u101))
(define-constant ERR_INVALID_AMOUNT (err u102))
(define-constant ERR_DRAWING_NOT_READY (err u103))
(define-constant ERR_NO_TICKETS_SOLD (err u104))
(define-constant ERR_ALREADY_DRAWN (err u105))
(define-constant ERR_TRANSFER_FAILED (err u106))
(define-constant ERR_INVALID_ROUND (err u107))

;; Ticket price in microSTX (100,000 = 0.1 STX)
(define-constant TICKET_PRICE u100000)
;; Operator fee percentage (10%)
(define-constant OPERATOR_FEE_PERCENT u10)
;; Minimum prize threshold in microSTX (10 STX = 10,000,000 microSTX)
(define-constant MIN_PRIZE_THRESHOLD u10000000)
;; Cutoff blocks before drawing (approximately 1 hour at 10-min blocks)
(define-constant CUTOFF_BLOCKS u6)

;; Data Variables
(define-data-var current-round uint u1)
(define-data-var round-start-block uint u0)
(define-data-var drawing-block uint u0)
(define-data-var is-active bool true)
(define-data-var total-tickets-current-round uint u0)
(define-data-var prize-pool uint u0)
(define-data-var carried-over-pool uint u0)

;; Data Maps
;; Map round -> ticket number -> owner
(define-map ticket-owners { round: uint, ticket-id: uint } principal)

;; Map round -> participant -> list of ticket IDs (stored as count for simplicity)
(define-map participant-ticket-count { round: uint, participant: principal } uint)

;; Map round -> winning info
(define-map round-results uint {
    winner: (optional principal),
    winning-ticket: uint,
    prize-amount: uint,
    block-hash-used: (buff 32),
    total-tickets: uint
})

;; Map round -> has been drawn
(define-map round-drawn uint bool)

;; Read-only functions

;; Get current round number
(define-read-only (get-current-round)
    (var-get current-round)
)

;; Get total tickets sold in current round
(define-read-only (get-tickets-sold)
    (var-get total-tickets-current-round)
)

;; Get current prize pool
(define-read-only (get-prize-pool)
    (+ (var-get prize-pool) (var-get carried-over-pool))
)

;; Get ticket price
(define-read-only (get-ticket-price)
    TICKET_PRICE
)

;; Get participant's ticket count for a round
(define-read-only (get-participant-tickets (round uint) (participant principal))
    (default-to u0 (map-get? participant-ticket-count { round: round, participant: participant }))
)

;; Get ticket owner
(define-read-only (get-ticket-owner (round uint) (ticket-id uint))
    (map-get? ticket-owners { round: round, ticket-id: ticket-id })
)

;; Get round results
(define-read-only (get-round-results (round uint))
    (map-get? round-results round)
)

;; Check if lottery is active
(define-read-only (is-lottery-active)
    (var-get is-active)
)

;; Get drawing block for current round
(define-read-only (get-drawing-block)
    (var-get drawing-block)
)

;; Check if within cutoff period (ticket sales closed)
(define-read-only (is-in-cutoff-period)
    (let ((draw-block (var-get drawing-block)))
        (if (is-eq draw-block u0)
            false
            (>= stacks-block-height (- draw-block CUTOFF_BLOCKS))
        )
    )
)

;; Calculate winner from block hash deterministically
(define-read-only (calculate-winner-from-hash (block-hash (buff 32)) (total-tickets uint))
    (if (is-eq total-tickets u0)
        u0
        (let (
            ;; Convert first 16 bytes of hash to uint for randomness
            (hash-as-uint (buff-to-uint-be (unwrap-panic (as-max-len? (unwrap-panic (slice? block-hash u0 u16)) u16))))
        )
            (+ (mod hash-as-uint total-tickets) u1)
        )
    )
)

;; Public functions

;; Buy tickets
(define-public (buy-tickets (quantity uint))
    (let (
        (round (var-get current-round))
        (total-cost (* quantity TICKET_PRICE))
        (current-ticket-count (var-get total-tickets-current-round))
        (buyer tx-sender)
    )
        ;; Validations
        (asserts! (var-get is-active) ERR_LOTTERY_NOT_ACTIVE)
        (asserts! (> quantity u0) ERR_INVALID_AMOUNT)
        (asserts! (not (is-in-cutoff-period)) ERR_DRAWING_NOT_READY)

        ;; Transfer STX from buyer to contract
        (try! (stx-transfer? total-cost buyer (as-contract tx-sender)))

        ;; Calculate operator fee and prize contribution
        (let (
            (operator-fee (/ (* total-cost OPERATOR_FEE_PERCENT) u100))
            (prize-contribution (- total-cost operator-fee))
        )
            ;; Add to prize pool
            (var-set prize-pool (+ (var-get prize-pool) prize-contribution))

            ;; Transfer operator fee to owner
            (try! (as-contract (stx-transfer? operator-fee tx-sender CONTRACT_OWNER)))
        )

        ;; Assign tickets to buyer
        (let ((start-ticket (+ current-ticket-count u1)))
            ;; Record each ticket
            (map set-ticket-owner
                (list
                    { round: round, ticket-id: start-ticket, owner: buyer }
                    { round: round, ticket-id: (+ start-ticket u1), owner: buyer }
                    { round: round, ticket-id: (+ start-ticket u2), owner: buyer }
                    { round: round, ticket-id: (+ start-ticket u3), owner: buyer }
                    { round: round, ticket-id: (+ start-ticket u4), owner: buyer }
                    { round: round, ticket-id: (+ start-ticket u5), owner: buyer }
                    { round: round, ticket-id: (+ start-ticket u6), owner: buyer }
                    { round: round, ticket-id: (+ start-ticket u7), owner: buyer }
                    { round: round, ticket-id: (+ start-ticket u8), owner: buyer }
                    { round: round, ticket-id: (+ start-ticket u9), owner: buyer }
                )
                (generate-ticket-flags quantity)
            )

            ;; Update total tickets
            (var-set total-tickets-current-round (+ current-ticket-count quantity))

            ;; Update participant ticket count
            (map-set participant-ticket-count
                { round: round, participant: buyer }
                (+ (get-participant-tickets round buyer) quantity)
            )
        )

        (ok quantity)
    )
)

;; Helper to set ticket owner (used with map)
(define-private (set-ticket-owner (ticket-data { round: uint, ticket-id: uint, owner: principal }) (should-set bool))
    (if should-set
        (begin
            (map-set ticket-owners
                { round: (get round ticket-data), ticket-id: (get ticket-id ticket-data) }
                (get owner ticket-data)
            )
            true
        )
        false
    )
)

;; Helper to generate flags for ticket assignment
(define-private (generate-ticket-flags (quantity uint))
    (list
        (>= quantity u1)
        (>= quantity u2)
        (>= quantity u3)
        (>= quantity u4)
        (>= quantity u5)
        (>= quantity u6)
        (>= quantity u7)
        (>= quantity u8)
        (>= quantity u9)
        (>= quantity u10)
    )
)

;; Set drawing block (owner only) - sets when the next drawing will happen
(define-public (set-drawing-block (target-block uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (> target-block stacks-block-height) ERR_INVALID_AMOUNT)
        (var-set drawing-block target-block)
        (ok true)
    )
)

;; Execute the daily drawing
(define-public (execute-drawing)
    (let (
        (round (var-get current-round))
        (draw-block (var-get drawing-block))
        (total-tickets (var-get total-tickets-current-round))
        (total-prize (get-prize-pool))
    )
        ;; Validations
        (asserts! (not (default-to false (map-get? round-drawn round))) ERR_ALREADY_DRAWN)
        (asserts! (> draw-block u0) ERR_DRAWING_NOT_READY)
        (asserts! (> stacks-block-height draw-block) ERR_DRAWING_NOT_READY)

        ;; Handle case where no tickets sold
        (if (is-eq total-tickets u0)
            (begin
                ;; Carry over prize pool and start new round
                (var-set carried-over-pool total-prize)
                (var-set prize-pool u0)
                (map-set round-drawn round true)
                (map-set round-results round {
                    winner: none,
                    winning-ticket: u0,
                    prize-amount: u0,
                    block-hash-used: 0x0000000000000000000000000000000000000000000000000000000000000000,
                    total-tickets: u0
                })
                (start-new-round)
                (ok u0)
            )
            (let (
                ;; Get Bitcoin block hash for randomness
                ;; Note: get-stacks-block-info? returns Stacks block info, we use burn-stacks-block-height for Bitcoin
                (block-hash (unwrap! (get-stacks-block-info? id-header-hash draw-block) ERR_DRAWING_NOT_READY))
                (winning-ticket-num (calculate-winner-from-hash block-hash total-tickets))
                (winner-principal (unwrap! (get-ticket-owner round winning-ticket-num) ERR_NO_TICKETS_SOLD))
            )
                ;; Check if prize meets minimum threshold
                (if (< total-prize MIN_PRIZE_THRESHOLD)
                    ;; Carry over to next round
                    (begin
                        (var-set carried-over-pool total-prize)
                        (var-set prize-pool u0)
                        (map-set round-drawn round true)
                        (map-set round-results round {
                            winner: none,
                            winning-ticket: u0,
                            prize-amount: u0,
                            block-hash-used: block-hash,
                            total-tickets: total-tickets
                        })
                        (start-new-round)
                        (ok u0)
                    )
                    ;; Pay winner
                    (begin
                        ;; Transfer prize to winner
                        (try! (as-contract (stx-transfer? total-prize tx-sender winner-principal)))

                        ;; Record results
                        (map-set round-drawn round true)
                        (map-set round-results round {
                            winner: (some winner-principal),
                            winning-ticket: winning-ticket-num,
                            prize-amount: total-prize,
                            block-hash-used: block-hash,
                            total-tickets: total-tickets
                        })

                        ;; Reset for new round
                        (var-set prize-pool u0)
                        (var-set carried-over-pool u0)
                        (start-new-round)

                        (ok winning-ticket-num)
                    )
                )
            )
        )
    )
)

;; Helper to start a new round
(define-private (start-new-round)
    (begin
        (var-set current-round (+ (var-get current-round) u1))
        (var-set total-tickets-current-round u0)
        (var-set round-start-block stacks-block-height)
        (var-set drawing-block u0)
        true
    )
)

;; Admin: Toggle lottery active status
(define-public (set-lottery-active (active bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set is-active active)
        (ok true)
    )
)

;; Initialize the contract (called once after deployment)
(define-public (initialize)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set round-start-block stacks-block-height)
        (ok true)
    )
)
