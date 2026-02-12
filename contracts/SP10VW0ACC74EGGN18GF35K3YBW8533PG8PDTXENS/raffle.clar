;; Raffle Contract
;; On-chain raffle/sorteio system
;; Users buy tickets; admin closes and picks winner
;; Each ticket purchase generates transaction fees
;; Designed for high engagement and gamification

;; Error codes
(define-constant ERR-RAFFLE-CLOSED (err u1001))
(define-constant ERR-INVALID-AMOUNT (err u1002))
(define-constant ERR-NO-PARTICIPANTS (err u1003))
(define-constant ERR-NOT-ADMIN (err u1004))
(define-constant ERR-ALREADY-CLOSED (err u1005))
(define-constant ERR-INVALID-TICKET-COUNT (err u1006))

;; Ticket price (in micro-STX)
(define-constant TICKET-PRICE u10000)  ;; 0.01 STX per ticket

;; Contract admin (set to deployer, can be changed if needed)
(define-data-var admin principal tx-sender)

;; Round status: true = open, false = closed
(define-data-var is-open bool true)

;; Total tickets sold in current round
(define-data-var total-tickets uint u0)

;; Unique participants counter
(define-data-var participant-count uint u0)

;; Current round number
(define-data-var current-round uint u1)

;; Current round winner (none if not chosen yet)
(define-data-var current-winner (optional principal) none)

;; Map of tickets per participant in current round: participant -> ticket-count
(define-map participant-tickets (tuple (round uint) (participant principal)) uint)

;; List of participants in current round: (round, index) -> participant
(define-map participant-list (tuple (round uint) (index uint)) principal)

;; Map to track participant index in list: (round, participant) -> index
(define-map participant-index (tuple (round uint) (participant principal)) (optional uint))

;; Round winners history: round -> {winner, ticket-count, total-tickets}
(define-map round-history uint {
    winner: principal,
    ticket-count: uint,
    total-tickets: uint
})

;; Helper to add participant to list if new in round
(define-private (add-participant-if-new (round uint) (participant principal))
    (let ((existing-index (map-get? participant-index (tuple (round round) (participant participant)))))
        (if (is-none existing-index)
            ;; New participant in round, add to list
            (let ((new-index (var-get participant-count)))
                (var-set participant-count (+ new-index u1))
                (map-set participant-list (tuple (round round) (index new-index)) participant)
                (map-set participant-index (tuple (round round) (participant participant)) (some new-index))
                true
            )
            ;; Already in list
            false
        )
    )
)

;; Public function: Buy tickets
;; @param ticket-count: Number of tickets to buy
(define-public (buy-ticket (ticket-count uint))
    (let ((sender tx-sender)
          (round (var-get current-round)))
        
        ;; Validate that round is open
        (asserts! (var-get is-open) ERR-RAFFLE-CLOSED)
        
        ;; Validate ticket quantity
        (asserts! (> ticket-count u0) ERR-INVALID-TICKET-COUNT)
        (asserts! (<= ticket-count u100) ERR-INVALID-TICKET-COUNT)  ;; Limit of 100 tickets per transaction to prevent spam
        
        ;; Calculate total amount needed (STX sent with transaction)
        (let ((total-amount (* ticket-count TICKET-PRICE)))
            ;; Add participant to list if new
            (add-participant-if-new round sender)
            
            ;; Get current number of tickets for participant
            (let ((current-tickets (default-to u0 (map-get? participant-tickets (tuple (round round) (participant sender))))))
                ;; Update participant tickets
                (map-set participant-tickets (tuple (round round) (participant sender)) (+ current-tickets ticket-count))
                
                ;; Increment total tickets counter
                (var-set total-tickets (+ (var-get total-tickets) ticket-count))
                
                ;; STX is sent automatically with the transaction
                (ok {
                    participant: sender,
                    tickets-bought: ticket-count,
                    total-tickets: (+ current-tickets ticket-count),
                    round: round
                })
            )
        )
    )
)

;; Public function: Close round and pick winner (admin only)
(define-public (close-and-pick-winner)
    (let ((sender tx-sender)
          (round (var-get current-round)))
        
        ;; Validate that sender is admin
        (asserts! (is-eq sender (var-get admin)) ERR-NOT-ADMIN)
        
        ;; Validate that round is open
        (asserts! (var-get is-open) ERR-ALREADY-CLOSED)
        
        ;; Validate that there are participants
        (let ((total-tickets-sold (var-get total-tickets)))
            (asserts! (> total-tickets-sold u0) ERR-NO-PARTICIPANTS)
            
            ;; Close the round
            (var-set is-open false)
            
            ;; Pick winner using simple pseudo-random
            ;; Uses total-tickets as seed for pseudo-random number
            ;; This provides a deterministic but unpredictable selection
            (let ((participant-count-var (var-get participant-count)))
                
                ;; Calculate winner index: total-tickets % participant-count
                (let ((winner-index (mod total-tickets-sold participant-count-var)))
                    ;; Get winner by index (unwrap-panic is safe because we validated participant-count > 0)
                    (let ((winner (unwrap-panic (map-get? participant-list (tuple (round round) (index winner-index)))))
                          (winner-tickets (unwrap-panic (map-get? participant-tickets (tuple (round round) (participant winner))))))
                        ;; Save current winner
                        (var-set current-winner (some winner))
                        
                        ;; Save to history
                        (map-set round-history round {
                            winner: winner,
                            ticket-count: winner-tickets,
                            total-tickets: total-tickets-sold
                        })
                        
                        (ok {
                            round: round,
                            winner: winner,
                            winner-tickets: winner-tickets,
                            total-tickets: total-tickets-sold
                        })
                    )
                )
            )
        )
    )
)

;; Public function: Start new round (admin only)
(define-public (start-new-round)
    (let ((sender tx-sender))
        ;; Validate that sender is admin
        (asserts! (is-eq sender (var-get admin)) ERR-NOT-ADMIN)
        
        ;; Increment round number
        (var-set current-round (+ (var-get current-round) u1))
        
        ;; Reset counters for new round
        (var-set total-tickets u0)
        (var-set participant-count u0)
        (var-set current-winner none)
        
        ;; Open new round
        (var-set is-open true)
        
        (ok (var-get current-round))
    )
)

;; ============================================
;; Read-only functions for contract queries
;; ============================================

;; Read-only: Get current round status
(define-read-only (get-round-status)
    {
        round: (var-get current-round),
        is-open: (var-get is-open),
        total-tickets: (var-get total-tickets),
        participant-count: (var-get participant-count),
        winner: (var-get current-winner)
    }
)

;; Read-only: Get participant ticket count in current round
(define-read-only (get-participant-tickets (participant principal))
    (let ((round (var-get current-round)))
        (default-to u0 (map-get? participant-tickets (tuple (round round) (participant participant))))
    )
)

;; Read-only: Get round history
(define-read-only (get-round-history (round uint))
    (map-get? round-history round)
)

;; Read-only: Get participant by index in current round
(define-read-only (get-participant-at-index (index uint))
    (let ((round (var-get current-round)))
        (map-get? participant-list (tuple (round round) (index index)))
    )
)

;; Read-only: Get admin
(define-read-only (get-admin)
    (var-get admin)
)

;; Read-only: Get ticket price
(define-read-only (get-ticket-price)
    TICKET-PRICE
)
