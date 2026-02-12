;; ------------------------------------------------------------
;; Tycoon Contract (Clarity)
;; Allows users to register, create, join, and manage game sessions
;; ------------------------------------------------------------

;; ---- GLOBAL STATE ----
(define-data-var latest-game-id uint u0)

;; ---- CONSTANTS ----
(define-constant STATUS_PENDING u1)
(define-constant STATUS_ONGOING u2)
(define-constant STATUS_ENDED u3)
(define-constant STAKE_AMOUNT u1000000000)
(define-constant CONTRACT-PRINCIPAL current-contract)



(define-constant MIN_TURNS_FOR_BONUS u10)
(define-constant BONUS_MULTIPLIER u150) ;; 1.5x as uint (150%)

;; ---- DATA MAPS ----
(define-map games 
  uint
  {
    id: uint,
    code: (string-ascii 32),
    creator: principal,
    game-type: uint,
    number-of-players: uint,
    ai: bool,
    winner: (optional principal),
    joined-players: uint,
    status: uint,
    next-player: principal,
    next-p: uint,
    created-at: uint,
    ended-at: uint,
    total-staked: uint,
    bet-amount: uint
  }
)

(define-map game-settings
  uint
  {
    max-players: uint,
    auction-enabled: bool,
    rent-in-prison: bool,
    mortgage-enabled: bool,
    even-build: bool,
    starting-cash: uint,
    private-code: (string-ascii 32)
  }
)

(define-map properties
  { game-id: uint, property-id: uint }
  {
    owner: principal,
    base-price: uint,
    current-rent: uint
  }
)

(define-map game-players
  { game-id: uint, player: principal }
  {
    balance: uint,
    player-symbol: uint,
    position: uint,
    order: uint,
    winner: (optional principal),
    username: (string-ascii 32)
  }
)

(define-map users
  principal
  { 
    username: (string-ascii 32), 
    registered-at: uint,
    games-played: uint,
    games-won: uint,
    games-lost: uint,
    total-staked: uint,
    total-earned: uint,
    total-withdrawn: uint
  }
)

(define-map usernames
  (string-ascii 32)
  principal
)
(define-map payouts
  principal
  uint
)
(define-map game-codes
  (string-ascii 32)
  {
    id: uint,
    code: (string-ascii 32),
    creator: principal,
    game-type: uint,
    number-of-players: uint,
    ai: bool,
    winner: (optional principal),
    joined-players: uint,
    status: uint,
    next-player: principal,
    next-p: uint,
    created-at: uint,
    ended-at: uint,
    total-staked: uint,
    bet-amount: uint
  }

)



;; ---- ERROR CONSTANTS ----
(define-constant ERR_ALREADY_REGISTERED (err u100))
(define-constant ERR_USERNAME_TAKEN (err u101))
(define-constant ERR_INVALID_USERNAME (err u102))
(define-constant ERR_INVALID_PLAYER_COUNT (err u103))
(define-constant ERR_INVALID_STARTING_BALANCE (err u104))
(define-constant ERR_NOT_REGISTERED (err u105))
(define-constant ERR_INVALID_BALANCE (err u106))
(define-constant ERR_GAME_NOT_ENDED (err u107))
(define-constant ERR_NO_WINNER (err u108))
(define-constant ERR_NOT_WINNER (err u109))
(define-constant ERR_ALREADY_CLAIMED (err u110))


(define-constant ERR_GAME_NOT_FOUND (err u200))
(define-constant ERR_USER_NOT_REGISTERED (err u201))
(define-constant ERR_GAME_NOT_OPEN (err u202))
(define-constant ERR_GAME_FULL (err u203))
(define-constant ERR_ALREADY_JOINED (err u204))
(define-constant ERR_PLAYER_NOT_IN_GAME (err u205))
(define-constant ERR_GAME_NOT_ONGOING (err u206))
(define-constant ERR_INVALID_PROPERTY_ID (err u207))
(define-constant ERR_NOT_PLAYER (err u208))

;; ---- READ-ONLY FUNCTIONS ----

(define-read-only (is-registered (user principal))
  (is-some (map-get? users user))
)

(define-read-only (get-user (user principal))
  (map-get? users user)
)

(define-read-only (get-game (game-id uint))
  (map-get? games game-id)
)

(define-read-only (get-game-settings (game-id uint))
  (map-get? game-settings game-id)
)

(define-read-only (get-property (game-id uint) (property-id uint))
  (map-get? properties { game-id: game-id, property-id: property-id })
)

(define-read-only (get-game-player (game-id uint) (player principal))
  (map-get? game-players { game-id: game-id, player: player })
)

(define-read-only (get-game-by-code (code (string-ascii 32)))
  (map-get? game-codes code)
)

(define-read-only (get-player-balance (player principal))
  (stx-get-balance player)
)

(define-read-only (get-owner)
  (stx-get-balance CONTRACT-PRINCIPAL)
)


;; ---- PUBLIC FUNCTIONS ----

(define-public (register (username (string-ascii 32)))
  (let (
      (caller tx-sender)
      (username-len (len username))
      (existing-user (map-get? users caller))
      (existing-username (map-get? usernames username))
    )
    (asserts! (not (is-some existing-user)) ERR_ALREADY_REGISTERED)
    (asserts! (and (> username-len u0) (<= username-len u32)) ERR_INVALID_USERNAME)
    (asserts! (not (is-some existing-username)) ERR_USERNAME_TAKEN)

    (map-set users caller { 
      username: username, 
      registered-at: stacks-block-time,
      games-played: u0,
      games-won: u0,
      games-lost: u0,
      total-staked: u0,
      total-earned: u0,
      total-withdrawn: u0
    })
    (map-set usernames username caller)
    (ok true)
  )
)
;; clarinet deployments apply --mainnet