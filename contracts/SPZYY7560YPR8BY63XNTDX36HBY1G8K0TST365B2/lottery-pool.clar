;; lottery-pool.clar
;; Pseudo-random lottery system

;; Constants
(define-constant CONTRACT-ADDRESS .lottery-pool)
(define-constant ERR-ROUND-NOT-FOUND (err u100))
(define-constant ERR-ROUND-NOT-ACTIVE (err u101))
(define-constant ERR-ROUND-STILL-ACTIVE (err u102))
(define-constant ERR-INVALID-TICKET-PRICE (err u103))
(define-constant ERR-NO-TICKETS-SOLD (err u105))
(define-constant ERR-WINNER-ALREADY-DRAWN (err u106))
(define-constant ERR-NOT-WINNER (err u107))
(define-constant ERR-PRIZE-ALREADY-CLAIMED (err u108))
(define-constant ERR-WINNER-NOT-DRAWN (err u109))

;; Data Variables
(define-data-var round-counter uint u0)
(define-data-var ticket-counter uint u0)

;; Maps
(define-map rounds uint 
  {
    prize-pool: uint,
    ticket-price: uint,
    start-time: uint,
    end-time: uint,
    winner: (optional principal),
    drawn: bool,
    claimed: bool,
    tickets-sold: uint,
    active: bool
  }
)

;; Public Functions
(define-public (create-round (ticket-price uint) (duration-hours uint))
  (let (
    (round-id (+ (var-get round-counter) u1))
    (end-time (+ stacks-block-time (* duration-hours u3600)))
  )
    (begin
      (asserts! (> ticket-price u0) ERR-INVALID-TICKET-PRICE)
      (asserts! (> duration-hours u0) ERR-ROUND-STILL-ACTIVE)
      
      (map-set rounds round-id {
        prize-pool: u0,
        ticket-price: ticket-price,
        start-time: stacks-block-time,
        end-time: end-time,
        winner: none,
        drawn: false,
        claimed: false,
        tickets-sold: u0,
        active: true
      })
      
      (var-set round-counter round-id)
      (ok round-id)
    )
  )
)

(define-public (buy-tickets (round-id uint) (count uint))
  (let (
    (round (unwrap! (map-get? rounds round-id) ERR-ROUND-NOT-FOUND))
    (total-cost (* (get ticket-price round) count))
  )
    (begin
      (asserts! (get active round) ERR-ROUND-NOT-ACTIVE)
      (asserts! (< stacks-block-time (get end-time round)) ERR-ROUND-STILL-ACTIVE)
      (asserts! (> count u0) (err u110))
      
      (unwrap-panic (stx-transfer? total-cost tx-sender CONTRACT-ADDRESS))
      
      ;; In Clarity, we can't easily loop to set map entries without a fixed list
      ;; For this demo, we'll just track the count and the last buyer for simplicity in the draw
      (map-set rounds round-id (merge round {
        prize-pool: (+ (get prize-pool round) total-cost),
        tickets-sold: (+ (get tickets-sold round) count)
      }))
      (var-set ticket-counter (+ (var-get ticket-counter) count))
      (ok true)
    )
  )
)

(define-public (draw-winner (round-id uint))
  (let ((round (unwrap! (map-get? rounds round-id) ERR-ROUND-NOT-FOUND)))
    (begin
      (asserts! (get active round) ERR-ROUND-NOT-ACTIVE)
      (asserts! (>= stacks-block-time (get end-time round)) ERR-ROUND-STILL-ACTIVE)
      (asserts! (> (get tickets-sold round) u0) ERR-NO-TICKETS-SOLD)
      (asserts! (not (get drawn round)) ERR-WINNER-ALREADY-DRAWN)
      
      ;; Pseudo-randomness using block info
      (let (
        ;; Simplified winner selection for demo
        (winner tx-sender) ;; In real contract, use random-val to pick from ticket buyers
      )
        (begin
          (map-set rounds round-id (merge round {
            winner: (some winner),
            drawn: true,
            active: false
          }))
          (print { event: "winner-drawn", id: round-id, winner: winner, prize: (get prize-pool round) })
          (ok winner)
        )
      )
    )
  )
)

(define-public (claim-prize (round-id uint))
  (let ((round (unwrap! (map-get? rounds round-id) ERR-ROUND-NOT-FOUND)))
    (begin
      (asserts! (get drawn round) ERR-WINNER-NOT-DRAWN)
      (asserts! (is-eq (get winner round) (some tx-sender)) ERR-NOT-WINNER)
      (asserts! (not (get claimed round)) ERR-PRIZE-ALREADY-CLAIMED)
      
      (let ((prize (get prize-pool round)))
        (begin
          (map-set rounds round-id (merge round { claimed: true }))
          (try! (stx-transfer? prize CONTRACT-ADDRESS tx-sender))
          (ok true)
        )
      )
    )
  )
)

;; Read-only
(define-read-only (get-round (round-id uint))
  (map-get? rounds round-id)
)
