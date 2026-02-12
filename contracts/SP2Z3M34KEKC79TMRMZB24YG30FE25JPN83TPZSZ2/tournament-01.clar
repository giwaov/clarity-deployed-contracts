;; TOURNAMENT CONTRACT
;; Manages competitive tournament brackets

;; ============================================================================
;; CONSTANTS
;; ============================================================================

(define-constant ERR_NOT_AUTHORIZED (err u800))
(define-constant ERR_NOT_FOUND (err u801))
(define-constant ERR_TOURNAMENT_FULL (err u802))
(define-constant ERR_TOURNAMENT_STARTED (err u803))
(define-constant ERR_INSUFFICIENT_FUNDS (err u804))

;; ============================================================================
;; DATA VARS
;; ============================================================================

(define-data-var tournament-id-nonce uint u0)

;; ============================================================================
;; DATA MAPS
;; ============================================================================

(define-map tournaments
  { tournament-id: uint }
  {
    name: (string-ascii 50),
    organizer: principal,
    difficulty: uint,
    entry-fee: uint,
    max-players: uint,
    current-players: uint,
    status: (string-ascii 20), ;; "open", "in-progress", "finished"
    prize-pool: uint,
    created-at: uint,
    started-at: (optional uint),
    finished-at: (optional uint),
    winner: (optional principal)
  }
)

(define-map tournament-participants
  { tournament-id: uint, player: principal }
  {
    entry-paid: bool,
    eliminated: bool,
    final-rank: uint,
    total-score: uint,
    games-played: (list 10 uint)
  }
)

(define-map tournament-rounds
  { tournament-id: uint, round: uint }
  {
    round-name: (string-ascii 20),
    total-matches: uint,
    completed-matches: uint,
    board-seed: (buff 32)
  }
)

;; ============================================================================
;; TOURNAMENT CREATION
;; ============================================================================

(define-public (create-tournament 
  (name (string-ascii 50))
  (difficulty uint)
  (entry-fee uint)
  (max-players uint))
  (let
    (
      (tournament-id (+ (var-get tournament-id-nonce) u1))
    )
    ;; Create tournament
    (map-set tournaments
      {tournament-id: tournament-id}
      {
        name: name,
        organizer: tx-sender,
        difficulty: difficulty,
        entry-fee: entry-fee,
        max-players: max-players,
        current-players: u0,
        status: "open",
        prize-pool: u0,
        created-at: stacks-block-height,
        started-at: none,
        finished-at: none,
        winner: none
      }
    )
    
    (var-set tournament-id-nonce tournament-id)
    (ok tournament-id)
  )
)

;; ============================================================================
;; TOURNAMENT PARTICIPATION
;; ============================================================================

(define-public (join-tournament (tournament-id uint))
  (let
    (
      (tournament (unwrap! (map-get? tournaments {tournament-id: tournament-id}) ERR_NOT_FOUND))
      (entry-fee (get entry-fee tournament))
    )
    ;; Validate
    (asserts! (is-eq (get status tournament) "open") ERR_TOURNAMENT_STARTED)
    (asserts! (< (get current-players tournament) (get max-players tournament)) ERR_TOURNAMENT_FULL)
    
    ;; Lock entry fee in economy contract
    (unwrap! (contract-call? .economy-01 lock-funds tournament-id entry-fee) ERR_INSUFFICIENT_FUNDS)
    
    ;; Add participant
    (map-set tournament-participants
      {tournament-id: tournament-id, player: tx-sender}
      {
        entry-paid: true,
        eliminated: false,
        final-rank: u0,
        total-score: u0,
        games-played: (list)
      }
    )
    
    ;; Update tournament
    (map-set tournaments
      {tournament-id: tournament-id}
      (merge tournament {
        current-players: (+ (get current-players tournament) u1),
        prize-pool: (+ (get prize-pool tournament) entry-fee)
      })
    )
    
    ;; Check if tournament is full - auto-start
    (if (is-eq (+ (get current-players tournament) u1) (get max-players tournament))
      (start-tournament tournament-id)
      (ok true)
    )
  )
)

;; ============================================================================
;; TOURNAMENT EXECUTION
;; ============================================================================

(define-public (start-tournament (tournament-id uint))
  (let
    (
      (tournament (unwrap! (map-get? tournaments {tournament-id: tournament-id}) ERR_NOT_FOUND))
    )
    ;; Validate
    (asserts! (is-eq (get organizer tournament) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status tournament) "open") ERR_TOURNAMENT_STARTED)
    
    ;; Update status
    (map-set tournaments
      {tournament-id: tournament-id}
      (merge tournament {
        status: "in-progress",
        started-at: (some stacks-block-height)
      })
    )
    
    ;; Generate round 1 board seed
    (let
      (
        (seed (sha256 (unwrap-panic (to-consensus-buff? stacks-block-height))))
      )
      (map-set tournament-rounds
        {tournament-id: tournament-id, round: u1}
        {
          round-name: "Round 1",
          total-matches: (get current-players tournament),
          completed-matches: u0,
          board-seed: seed
        }
      )
      (ok true)
    )
  )
)

;; Submit game result for tournament
(define-public (submit-tournament-result (tournament-id uint) (game-id uint))
  (let
    (
      (tournament (unwrap! (map-get? tournaments {tournament-id: tournament-id}) ERR_NOT_FOUND))
      ;; Get game info from game-core
      (game (unwrap! (contract-call? .game-core-01 get-game-info game-id) ERR_NOT_FOUND))
      (participant (unwrap! (map-get? tournament-participants {tournament-id: tournament-id, player: tx-sender}) ERR_NOT_AUTHORIZED))
    )
    ;; Validate
    (asserts! (is-eq (get status tournament) "in-progress") ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get player game) tx-sender) ERR_NOT_AUTHORIZED)
    
    ;; Update participant score
    (map-set tournament-participants
      {tournament-id: tournament-id, player: tx-sender}
      (merge participant {
        total-score: (+ (get total-score participant) (default-to u0 (get final-score game))),
        games-played: (unwrap-panic (as-max-len? (append (get games-played participant) game-id) u10))
      })
    )
    
    (ok true)
  )
)

;; Finalize tournament and distribute prizes
(define-public (finalize-tournament (tournament-id uint))
  (let
    (
      (tournament (unwrap! (map-get? tournaments {tournament-id: tournament-id}) ERR_NOT_FOUND))
      (prize-pool (get prize-pool tournament))
    )
    ;; Validate
    (asserts! (is-eq (get organizer tournament) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status tournament) "in-progress") ERR_NOT_AUTHORIZED)
    
    ;; Update status
    (map-set tournaments
      {tournament-id: tournament-id}
      (merge tournament {
        status: "finished",
        finished-at: (some stacks-block-height)
      })
    )
    
    ;; Distribute prizes (simplified - in production, calculate rankings)
    ;; 1st place: 50%, 2nd: 30%, 3rd: 10%, 4th: 5%, platform: 5%
    
    (ok true)
  )
)

;; ============================================================================
;; READ-ONLY FUNCTIONS
;; ============================================================================

(define-read-only (get-tournament-info (tournament-id uint))
  (ok (map-get? tournaments {tournament-id: tournament-id}))
)

(define-read-only (get-participant-info (tournament-id uint) (player principal))
  (ok (map-get? tournament-participants {tournament-id: tournament-id, player: player}))
)

(define-read-only (get-round-info (tournament-id uint) (round uint))
  (ok (map-get? tournament-rounds {tournament-id: tournament-id, round: round}))
)
