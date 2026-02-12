;; Bitcoin Daily Lottery Contract (x402 Version)
;; A provably fair lottery using Bitcoin block hashes for randomness
;; Supports x402 payments via sBTC - operator mints tickets after receiving payment

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
(define-constant ERR_INSUFFICIENT_FUNDS (err u108))

;; Ticket price in sats (100 sats = 0.000001 BTC)
(define-constant TICKET_PRICE_SATS u100)
;; Minimum prize threshold in microSTX (1 STX = 1,000,000 microSTX)
(define-constant MIN_PRIZE_THRESHOLD u1000000)
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

;; Map round -> participant -> ticket count
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

;; ============================================
;; Read-only functions
;; ============================================

(define-read-only (get-current-round)
    (var-get current-round)
)

(define-read-only (get-tickets-sold)
    (var-get total-tickets-current-round)
)

(define-read-only (get-prize-pool)
    (+ (var-get prize-pool) (var-get carried-over-pool))
)

(define-read-only (get-ticket-price-sats)
    TICKET_PRICE_SATS
)

(define-read-only (get-participant-tickets (round uint) (participant principal))
    (default-to u0 (map-get? participant-ticket-count { round: round, participant: participant }))
)

(define-read-only (get-ticket-owner (round uint) (ticket-id uint))
    (map-get? ticket-owners { round: round, ticket-id: ticket-id })
)

(define-read-only (get-round-results (round uint))
    (map-get? round-results round)
)

(define-read-only (is-lottery-active)
    (var-get is-active)
)

(define-read-only (get-drawing-block)
    (var-get drawing-block)
)

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
            (hash-as-uint (buff-to-uint-be (unwrap-panic (as-max-len? (unwrap-panic (slice? block-hash u0 u16)) u16))))
        )
            (+ (mod hash-as-uint total-tickets) u1)
        )
    )
)

;; ============================================
;; x402 Payment Functions (Operator-only)
;; ============================================

;; Mint tickets for a recipient after x402 payment received
;; Called by operator backend after sBTC payment verified
(define-public (mint-tickets-for (recipient principal) (quantity uint))
    (let (
        (round (var-get current-round))
        (current-ticket-count (var-get total-tickets-current-round))
    )
        ;; Only operator can mint
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (var-get is-active) ERR_LOTTERY_NOT_ACTIVE)
        (asserts! (> quantity u0) ERR_INVALID_AMOUNT)
        (asserts! (<= quantity u10) ERR_INVALID_AMOUNT)
        (asserts! (not (is-in-cutoff-period)) ERR_DRAWING_NOT_READY)

        ;; Assign tickets to recipient
        (let ((start-ticket (+ current-ticket-count u1)))
            (map set-ticket-owner
                (list
                    { round: round, ticket-id: start-ticket, owner: recipient }
                    { round: round, ticket-id: (+ start-ticket u1), owner: recipient }
                    { round: round, ticket-id: (+ start-ticket u2), owner: recipient }
                    { round: round, ticket-id: (+ start-ticket u3), owner: recipient }
                    { round: round, ticket-id: (+ start-ticket u4), owner: recipient }
                    { round: round, ticket-id: (+ start-ticket u5), owner: recipient }
                    { round: round, ticket-id: (+ start-ticket u6), owner: recipient }
                    { round: round, ticket-id: (+ start-ticket u7), owner: recipient }
                    { round: round, ticket-id: (+ start-ticket u8), owner: recipient }
                    { round: round, ticket-id: (+ start-ticket u9), owner: recipient }
                )
                (generate-ticket-flags quantity)
            )

            ;; Update total tickets
            (var-set total-tickets-current-round (+ current-ticket-count quantity))

            ;; Update participant ticket count
            (map-set participant-ticket-count
                { round: round, participant: recipient }
                (+ (get-participant-tickets round recipient) quantity)
            )
        )

        (ok quantity)
    )
)

;; Fund the prize pool (operator deposits STX)
;; Operator converts sBTC revenue to STX and deposits here
(define-public (fund-prize-pool (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)

        ;; Transfer STX from operator to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))

        ;; Add to prize pool
        (var-set prize-pool (+ (var-get prize-pool) amount))

        (ok amount)
    )
)

;; ============================================
;; Helper Functions
;; ============================================

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

(define-private (start-new-round)
    (begin
        (var-set current-round (+ (var-get current-round) u1))
        (var-set total-tickets-current-round u0)
        (var-set round-start-block stacks-block-height)
        (var-set drawing-block u0)
        true
    )
)

;; ============================================
;; Drawing Functions
;; ============================================

;; Set drawing block (owner only)
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
                (block-hash (unwrap! (get-stacks-block-info? id-header-hash draw-block) ERR_DRAWING_NOT_READY))
                (winning-ticket-num (calculate-winner-from-hash block-hash total-tickets))
                (winner-principal (unwrap! (get-ticket-owner round winning-ticket-num) ERR_NO_TICKETS_SOLD))
            )
                ;; Check if prize meets minimum threshold
                (if (< total-prize MIN_PRIZE_THRESHOLD)
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

;; ============================================
;; Admin Functions
;; ============================================

(define-public (set-lottery-active (active bool))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set is-active active)
        (ok true)
    )
)

(define-public (initialize)
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (var-set round-start-block stacks-block-height)
        (ok true)
    )
)

;; Emergency withdraw (owner only) - for contract migration
(define-public (emergency-withdraw (amount uint))
    (begin
        (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
        (try! (as-contract (stx-transfer? amount tx-sender CONTRACT_OWNER)))
        (ok amount)
    )
)
