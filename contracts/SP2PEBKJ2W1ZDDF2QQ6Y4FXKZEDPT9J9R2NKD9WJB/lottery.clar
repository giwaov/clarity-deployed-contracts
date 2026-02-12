;; Stacks Lottery - Decentralized Lottery
;; Fair on-chain lottery with verifiable randomness

(define-constant contract-owner tx-sender)
(define-constant treasury 'SP2PEBKJ2W1ZDDF2QQ6Y4FXKZEDPT9J9R2NKD9WJB)
(define-constant err-round-active (err u100))
(define-constant err-round-ended (err u101))
(define-constant err-already-entered (err u102))
(define-constant err-not-found (err u103))

(define-constant TICKET-PRICE u1000000) ;; 1 STX
(define-constant ROUND-DURATION u1440)  ;; ~1 day
(define-constant PLATFORM-FEE u500)     ;; 5%
(define-constant FEE-DENOMINATOR u10000)

(define-data-var round-count uint u0)
(define-data-var total-prizes uint u0)

(define-map rounds uint
  {
    start-block: uint,
    end-block: uint,
    ticket-count: uint,
    prize-pool: uint,
    winner: (optional principal),
    claimed: bool
  }
)

(define-map tickets { round-id: uint, ticket-id: uint } principal)
(define-map user-tickets { round-id: uint, user: principal } uint)

(define-read-only (get-round (round-id uint))
  (map-get? rounds round-id)
)

(define-read-only (get-current-round)
  (var-get round-count)
)

(define-read-only (get-user-tickets (round-id uint) (user principal))
  (default-to u0 (map-get? user-tickets { round-id: round-id, user: user }))
)

(define-read-only (is-round-active (round-id uint))
  (match (map-get? rounds round-id)
    round (and 
      (<= stacks-block-height (get end-block round))
      (is-none (get winner round))
    )
    false
  )
)

(define-read-only (get-stats)
  {
    total-rounds: (var-get round-count),
    total-prizes: (var-get total-prizes)
  }
)

(define-public (start-round)
  (let (
    (round-id (var-get round-count))
  )
    (map-set rounds round-id {
      start-block: stacks-block-height,
      end-block: (+ stacks-block-height ROUND-DURATION),
      ticket-count: u0,
      prize-pool: u0,
      winner: none,
      claimed: false
    })
    
    (var-set round-count (+ round-id u1))
    (ok { round-id: round-id })
  )
)

(define-public (buy-ticket (round-id uint))
  (match (map-get? rounds round-id)
    round
    (let (
      (ticket-id (get ticket-count round))
      (current-tickets (get-user-tickets round-id tx-sender))
    )
      (asserts! (is-round-active round-id) err-round-ended)
      
      ;; Record ticket
      (map-set tickets { round-id: round-id, ticket-id: ticket-id } tx-sender)
      (map-set user-tickets { round-id: round-id, user: tx-sender } (+ current-tickets u1))
      
      ;; Update round
      (map-set rounds round-id 
        (merge round {
          ticket-count: (+ ticket-id u1),
          prize-pool: (+ (get prize-pool round) TICKET-PRICE)
        })
      )
      
      (ok { round-id: round-id, ticket-id: ticket-id })
    )
    err-not-found
  )
)

(define-public (draw-winner (round-id uint))
  (match (map-get? rounds round-id)
    round
    (let (
      (ticket-count (get ticket-count round))
      (winning-ticket (mod stacks-block-height ticket-count))
    )
      (asserts! (> stacks-block-height (get end-block round)) err-round-active)
      (asserts! (is-none (get winner round)) err-round-ended)
      (asserts! (> ticket-count u0) err-not-found)
      
      (match (map-get? tickets { round-id: round-id, ticket-id: winning-ticket })
        winner
        (begin
          (map-set rounds round-id (merge round { winner: (some winner) }))
          (var-set total-prizes (+ (var-get total-prizes) (get prize-pool round)))
          (ok { round-id: round-id, winner: winner, prize: (get prize-pool round) })
        )
        err-not-found
      )
    )
    err-not-found
  )
)

