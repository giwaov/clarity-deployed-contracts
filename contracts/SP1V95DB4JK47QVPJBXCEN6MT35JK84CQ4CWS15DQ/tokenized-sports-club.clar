(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-CLUB-NOT-FOUND (err u101))
(define-constant ERR-INSUFFICIENT-BALANCE (err u102))

(define-map sports-clubs
  { club-id: uint }
  {
    club-name: (string-ascii 100),
    sport: (string-ascii 30),
    location: (string-ascii 100),
    total-tokens: uint,
    tokens-issued: uint,
    token-price: uint,
    founder: principal,
    established-at: uint
  }
)

(define-map token-balances
  { club-id: uint, holder: principal }
  uint
)

(define-map governance-proposals
  { club-id: uint, proposal-id: uint }
  {
    title: (string-ascii 100),
    description: (string-ascii 200),
    proposer: principal,
    votes-for: uint,
    votes-against: uint,
    status: (string-ascii 20),
    created-at: uint
  }
)

(define-data-var club-nonce uint u0)

(define-public (create-club
  (club-name (string-ascii 100))
  (sport (string-ascii 30))
  (location (string-ascii 100))
  (total-tokens uint)
  (token-price uint)
)
  (let ((club-id (var-get club-nonce)))
    (map-set sports-clubs
      { club-id: club-id }
      {
        club-name: club-name,
        sport: sport,
        location: location,
        total-tokens: total-tokens,
        tokens-issued: u0,
        token-price: token-price,
        founder: tx-sender,
        established-at: stacks-block-height
      }
    )
    (var-set club-nonce (+ club-id u1))
    (ok club-id)
  )
)

(define-public (purchase-tokens (club-id uint) (amount uint))
  (let (
    (club (unwrap! (map-get? sports-clubs { club-id: club-id }) ERR-CLUB-NOT-FOUND))
    (current-balance (default-to u0 (map-get? token-balances { club-id: club-id, holder: tx-sender })))
  )
    (asserts! (<= (+ (get tokens-issued club) amount) (get total-tokens club)) ERR-INSUFFICIENT-BALANCE)
    (map-set token-balances
      { club-id: club-id, holder: tx-sender }
      (+ current-balance amount)
    )
    (ok (map-set sports-clubs
      { club-id: club-id }
      (merge club { tokens-issued: (+ (get tokens-issued club) amount) })
    ))
  )
)

(define-public (transfer-tokens (club-id uint) (amount uint) (recipient principal))
  (let (
    (sender-balance (default-to u0 (map-get? token-balances { club-id: club-id, holder: tx-sender })))
    (recipient-balance (default-to u0 (map-get? token-balances { club-id: club-id, holder: recipient })))
  )
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    (map-set token-balances { club-id: club-id, holder: tx-sender } (- sender-balance amount))
    (ok (map-set token-balances { club-id: club-id, holder: recipient } (+ recipient-balance amount)))
  )
)

(define-public (create-proposal
  (club-id uint)
  (proposal-id uint)
  (title (string-ascii 100))
  (description (string-ascii 200))
)
  (let ((club (unwrap! (map-get? sports-clubs { club-id: club-id }) ERR-CLUB-NOT-FOUND)))
    (ok (map-set governance-proposals
      { club-id: club-id, proposal-id: proposal-id }
      {
        title: title,
        description: description,
        proposer: tx-sender,
        votes-for: u0,
        votes-against: u0,
        status: "active",
        created-at: stacks-block-height
      }
    ))
  )
)

(define-read-only (get-club-info (club-id uint))
  (map-get? sports-clubs { club-id: club-id })
)

(define-read-only (get-balance (club-id uint) (holder principal))
  (ok (default-to u0 (map-get? token-balances { club-id: club-id, holder: holder })))
)

(define-read-only (get-proposal (club-id uint) (proposal-id uint))
  (map-get? governance-proposals { club-id: club-id, proposal-id: proposal-id })
)
