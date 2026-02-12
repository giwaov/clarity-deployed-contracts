;; STX Daily Raffle Contract
;; A simple raffle where users buy tickets with STX and one winner takes the pot

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-amount (err u101))
(define-constant err-no-tickets (err u102))
(define-constant err-transfer-failed (err u103))

;; Ticket price: 0.1 STX = 100,000 micro-STX
(define-constant ticket-price u100000)

;; Platform fee: 5%
(define-constant platform-fee-percent u5)

;; Data Variables
(define-data-var current-round uint u1)
(define-data-var current-pot uint u0)
(define-data-var total-tickets-current-round uint u0)

;; Data Maps
(define-map tickets 
    { round: uint, ticket-id: uint } 
    { buyer: principal }
)

(define-map player-tickets 
    { player: principal, round: uint } 
    { count: uint }
)

(define-map round-winners 
    { round: uint } 
    { winner: principal, pot-size: uint }
)

;; Read-Only Functions
(define-read-only (get-current-round)
    (var-get current-round)
)

(define-read-only (get-current-pot)
    (var-get current-pot)
)

(define-read-only (get-total-tickets)
    (var-get total-tickets-current-round)
)

(define-read-only (get-ticket-price)
    ticket-price
)

(define-read-only (get-my-tickets)
    (default-to 
        u0 
        (get count (map-get? player-tickets { player: tx-sender, round: (var-get current-round) }))
    )
)

(define-read-only (get-round-winner (round uint))
    (map-get? round-winners { round: round })
)

;; Public Functions
(define-public (buy-ticket)
    (let
        (
            (round (var-get current-round))
            (ticket-id (+ (var-get total-tickets-current-round) u1))
            (buyer tx-sender)
            (current-player-tickets (default-to u0 (get count (map-get? player-tickets { player: buyer, round: round }))))
        )
        (try! (stx-transfer? ticket-price buyer (as-contract tx-sender)))
        
        (map-set tickets 
            { round: round, ticket-id: ticket-id }
            { buyer: buyer }
        )
        
        (map-set player-tickets
            { player: buyer, round: round }
            { count: (+ current-player-tickets u1) }
        )
        
        (var-set total-tickets-current-round ticket-id)
        (var-set current-pot (+ (var-get current-pot) ticket-price))
        
        (ok ticket-id)
    )
)

(define-public (draw-winner)
    (let
        (
            (round (var-get current-round))
            (total-tickets (var-get total-tickets-current-round))
            (pot (var-get current-pot))
            (random-seed (mod stacks-block-height total-tickets))
            (winning-ticket-id (+ random-seed u1))
            (winner-data (map-get? tickets { round: round, ticket-id: winning-ticket-id }))
            (fee-amount (/ (* pot platform-fee-percent) u100))
            (winner-amount (- pot fee-amount))
        )
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (asserts! (> total-tickets u0) err-no-tickets)
        
        (match winner-data
            winner-info
            (let
                (
                    (winner-address (get buyer winner-info))
                )
                (try! (as-contract (stx-transfer? winner-amount tx-sender winner-address)))
                (try! (as-contract (stx-transfer? fee-amount tx-sender contract-owner)))
                
                (map-set round-winners
                    { round: round }
                    { winner: winner-address, pot-size: pot }
                )
                
                (var-set current-round (+ round u1))
                (var-set current-pot u0)
                (var-set total-tickets-current-round u0)
                
                (ok winner-address)
            )
            err-no-tickets
        )
    )
)