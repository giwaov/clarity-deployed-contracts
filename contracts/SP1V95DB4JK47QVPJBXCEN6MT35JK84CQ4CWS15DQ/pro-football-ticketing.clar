(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-TICKET-NOT-AVAILABLE (err u101))
(define-constant ERR-TICKET-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-USED (err u103))

(define-map games
  { game-id: uint }
  {
    home-team: (string-ascii 50),
    away-team: (string-ascii 50),
    stadium: (string-ascii 100),
    game-time: uint,
    total-tickets: uint,
    available-tickets: uint,
    organizer: principal
  }
)

(define-map tickets
  { game-id: uint, ticket-id: uint }
  {
    section: (string-ascii 20),
    row: (string-ascii 10),
    seat: (string-ascii 10),
    holder: principal,
    price: uint,
    purchased-at: uint,
    used: bool
  }
)

(define-data-var game-nonce uint u0)
(define-data-var ticket-nonce uint u0)

(define-public (create-game
  (home-team (string-ascii 50))
  (away-team (string-ascii 50))
  (stadium (string-ascii 100))
  (game-time uint)
  (total-tickets uint)
)
  (let ((game-id (var-get game-nonce)))
    (map-set games
      { game-id: game-id }
      {
        home-team: home-team,
        away-team: away-team,
        stadium: stadium,
        game-time: game-time,
        total-tickets: total-tickets,
        available-tickets: total-tickets,
        organizer: tx-sender
      }
    )
    (var-set game-nonce (+ game-id u1))
    (ok game-id)
  )
)

(define-public (purchase-ticket
  (game-id uint)
  (section (string-ascii 20))
  (row (string-ascii 10))
  (seat (string-ascii 10))
  (price uint)
)
  (let (
    (game (unwrap! (map-get? games { game-id: game-id }) ERR-TICKET-NOT-AVAILABLE))
    (ticket-id (var-get ticket-nonce))
  )
    (asserts! (> (get available-tickets game) u0) ERR-TICKET-NOT-AVAILABLE)
    (map-set tickets
      { game-id: game-id, ticket-id: ticket-id }
      {
        section: section,
        row: row,
        seat: seat,
        holder: tx-sender,
        price: price,
        purchased-at: stacks-block-height,
        used: false
      }
    )
    (map-set games
      { game-id: game-id }
      (merge game { available-tickets: (- (get available-tickets game) u1) })
    )
    (var-set ticket-nonce (+ ticket-id u1))
    (ok ticket-id)
  )
)

(define-public (use-ticket (game-id uint) (ticket-id uint))
  (let (
    (ticket (unwrap! (map-get? tickets { game-id: game-id, ticket-id: ticket-id }) ERR-TICKET-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get holder ticket)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get used ticket)) ERR-ALREADY-USED)
    (ok (map-set tickets
      { game-id: game-id, ticket-id: ticket-id }
      (merge ticket { used: true })
    ))
  )
)

(define-read-only (get-game-info (game-id uint))
  (map-get? games { game-id: game-id })
)

(define-read-only (get-ticket-info (game-id uint) (ticket-id uint))
  (map-get? tickets { game-id: game-id, ticket-id: ticket-id })
)

(define-public (transfer-ticket (game-id uint) (ticket-id uint) (new-holder principal))
  (let (
    (ticket (unwrap! (map-get? tickets { game-id: game-id, ticket-id: ticket-id }) ERR-TICKET-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get holder ticket)) ERR-NOT-AUTHORIZED)
    (ok (map-set tickets
      { game-id: game-id, ticket-id: ticket-id }
      (merge ticket { holder: new-holder })
    ))
  )
)
