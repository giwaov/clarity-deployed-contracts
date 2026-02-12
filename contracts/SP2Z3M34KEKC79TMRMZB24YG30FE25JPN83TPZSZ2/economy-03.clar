;; ECONOMY CONTRACT - Prize Pools + Reward Distribution (merged)
;; Manages all funds, escrow, and token rewards

;; ============================================================================
;; CONSTANTS
;; ============================================================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u700))
(define-constant ERR_INSUFFICIENT_BALANCE (err u701))
(define-constant ERR_TRANSFER_FAILED (err u702))

(define-constant PLATFORM_FEE_PERCENT u5) ;; 5%
(define-constant BASE_REWARD_TOKENS u10)

;; ============================================================================
;; DATA VARS
;; ============================================================================

(define-data-var platform-treasury uint u0)
(define-data-var total-rewards-distributed uint u0)
(define-data-var reward-pool-balance uint u100000000) ;; 100M initial tokens

;; ============================================================================
;; DATA MAPS
;; ============================================================================

;; Prize pools (for tournaments, wagers, etc.)
(define-map prize-pools
  { pool-id: uint }
  {
    pool-type: (string-ascii 20),
    total-amount: uint,
    distributed: bool,
    created-at: uint
  }
)

;; Escrow balances
(define-map escrow-balances
  { pool-id: uint, player: principal }
  { locked-amount: uint }
)

;; Pending rewards (tokens)
(define-map pending-rewards
  { player: principal }
  {
    platform-tokens: uint,
    stx-amount: uint,
    last-updated: uint
  }
)

;; Claimed rewards history
(define-map claimed-rewards
  { player: principal }
  {
    total-tokens-claimed: uint,
    total-stx-claimed: uint,
    last-claim-at: uint
  }
)

;; ============================================================================
;; REWARD CALCULATION
;; ============================================================================

;; Calculate and add rewards for game completion
(define-public (calculate-rewards (game-id uint))
  (let
    (
      ;; Get game information
      (game (unwrap! (contract-call? .game-core-02 get-game-info game-id) ERR_NOT_AUTHORIZED))
      (player (get player game))
      (won (is-eq (get status game) "won"))
      (difficulty (get difficulty game))
      (time (default-to u0 (get final-time game)))
      (score (default-to u0 (get final-score game)))
      
      ;; Base reward
      (base BASE_REWARD_TOKENS)
      
      ;; Win bonus
      (win-bonus (if won u50 u0))
      
      ;; Difficulty multiplier
      (diff-mult (if (is-eq difficulty u1) u1 (if (is-eq difficulty u2) u2 u4)))
     
      ;; Speed bonus (max 100 tokens)
      (speed-bonus (if (< time u100) (- u100 time) u0))
      
      ;; Get win streak multiplier from player profile
      (streak-mult (contract-call? .player-profile-02 get-streak-multiplier player))
      
      ;; Calculate total
      (subtotal (+ (+ base win-bonus) speed-bonus))
      (with-difficulty (* subtotal diff-mult))
      (final-tokens (* with-difficulty streak-mult))
    )
    ;; Add to pending rewards
    (begin
      (add-pending-rewards player final-tokens u0)
      (print {event: "calculate-rewards", game-id: game-id, player: player, tokens: final-tokens, won: won, difficulty: difficulty})
      (ok final-tokens)
    )
  )
)

;; Add tokens to pending rewards
(define-private (add-pending-rewards (player principal) (tokens uint) (stx uint))
  (let
    (
      (current (default-to {platform-tokens: u0, stx-amount: u0, last-updated: u0} 
                           (map-get? pending-rewards {player: player})))
    )
    (map-set pending-rewards
      {player: player}
      {
        platform-tokens: (+ (get platform-tokens current) tokens),
        stx-amount: (+ (get stx-amount current) stx),
        last-updated: stacks-block-height
      }
    )
    true
  )
)

;; ============================================================================
;; ACHIEVEMENT BONUSES
;; ============================================================================

;; Public function to add pending rewards (for external contracts like daily-challenge)
(define-public (add-rewards (player principal) (tokens uint) (stx uint))
  (begin
    (add-pending-rewards player tokens stx)
    (print {event: "add-rewards", player: player, tokens: tokens, stx: stx})
    (ok true)
  )
)

(define-public (award-achievement-bonus (player principal) (achievement-id uint))
  (let
    (
      ;; Different bonuses per achievement
      (bonus (get-achievement-bonus achievement-id))
    )
    (begin
      (add-pending-rewards player bonus u0)
      (print {event: "award-achievement-bonus", player: player, achievement-id: achievement-id, bonus: bonus})
      (ok bonus)
    )
  )
)

(define-private (get-achievement-bonus (achievement-id uint))
  ;; Legendary achievements = 1000 tokens
  ;; Epic = 500
  ;; Rare = 100
  ;; Common = 50
  (if (or (is-eq achievement-id u12) (is-eq achievement-id u13))
    u1000 ;; World Record, Tournament Victor
    (if (is-eq achievement-id u11)
      u500 ;; Century Club
      (if (or (is-eq achievement-id u2) (is-eq achievement-id u3) (is-eq achievement-id u4))
        u100 ;; Master achievements
        u50 ;; Others
      )
    )
  )
)

;; ============================================================================
;; CLAIM REWARDS
;; ============================================================================

;; Claim pending rewards
(define-public (claim-rewards)
  (let
    (
      (player tx-sender)
      (pending (unwrap! (map-get? pending-rewards {player: player}) ERR_INSUFFICIENT_BALANCE))
      (tokens (get platform-tokens pending))
      (stx (get stx-amount pending))
      (claimed (default-to {total-tokens-claimed: u0, total-stx-claimed: u0, last-claim-at: u0}
                          (map-get? claimed-rewards {player: player})))
    )
    ;; Validate has rewards
    (asserts! (or (> tokens u0) (> stx u0)) ERR_INSUFFICIENT_BALANCE)
    
    ;; Transfer tokens (in production, use FT transfer)
    ;; For now, just update balances
    
    ;; Update claimed history
    (map-set claimed-rewards
      {player: player}
      {
        total-tokens-claimed: (+ (get total-tokens-claimed claimed) tokens),
        total-stx-claimed: (+ (get total-stx-claimed claimed) stx),
        last-claim-at: stacks-block-height
      }
    )
    
    ;; Clear pending
    (map-set pending-rewards
      {player: player}
      {
        platform-tokens: u0,
        stx-amount: u0,
        last-updated: stacks-block-height
      }
    )
    
    ;; Update totals
    (var-set total-rewards-distributed (+ (var-get total-rewards-distributed) tokens))
    
    (print {event: "claim-rewards", player: player, tokens: tokens, stx: stx})
    (ok {tokens: tokens, stx: stx})
  )
)

;; ============================================================================
;; PRIZE POOL MANAGEMENT
;; ============================================================================

;; Lock funds in escrow
(define-public (lock-funds (pool-id uint) (amount uint))
  (let
    (
      (player tx-sender)
    )
    ;; In production, transfer STX to contract
    ;; For now, just track
    (map-set escrow-balances
      {pool-id: pool-id, player: player}
      {locked-amount: amount}
    )
    (print {event: "lock-funds", pool-id: pool-id, player: player, amount: amount})
    (ok true)
  )
)

;; Release funds to winner
(define-public (release-funds (pool-id uint) (winner principal) (amount uint))
  (let
    (
      (pool (unwrap! (map-get? prize-pools {pool-id: pool-id}) ERR_NOT_AUTHORIZED))
    )
    ;; Validate not already distributed
    (asserts! (not (get distributed pool)) ERR_NOT_AUTHORIZED)
    
    ;; Calculate platform fee
    (let
      (
        (fee (/ (* amount PLATFORM_FEE_PERCENT) u100))
        (net-amount (- amount fee))
      )
      ;; Add STX to winner's pending rewards
      (begin
        (add-pending-rewards winner u0 net-amount)
        true
      )
      
      ;; Add fee to treasury
      (var-set platform-treasury (+ (var-get platform-treasury) fee))
      
      ;; Mark as distributed
      (map-set prize-pools
        {pool-id: pool-id}
        (merge pool {distributed: true})
      )
      
      (print {event: "release-funds", pool-id: pool-id, winner: winner, amount: amount, net-amount: net-amount, fee: fee})
      (ok net-amount)
    )
  )
)

;; Refund escrowed funds
(define-public (refund-funds (pool-id uint))
  (let
    (
      (player tx-sender)
      (escrow (unwrap! (map-get? escrow-balances {pool-id: pool-id, player: player}) ERR_NOT_AUTHORIZED))
      (amount (get locked-amount escrow))
    )
    ;; In production, transfer STX back
    ;; Clear escrow
    (map-delete escrow-balances {pool-id: pool-id, player: player})
    
    (print {event: "refund-funds", pool-id: pool-id, player: player, amount: amount})
    (ok amount)
  )
)

;; ============================================================================
;; READ-ONLY FUNCTIONS
;; ============================================================================

;; Get pending rewards
(define-read-only (get-pending-rewards (player principal))
  (ok (map-get? pending-rewards {player: player}))
)

;; Get claimed rewards
(define-read-only (get-claimed-rewards (player principal))
  (ok (map-get? claimed-rewards {player: player}))
)

;; Get treasury balance
(define-read-only (get-treasury-balance)
  (ok (var-get platform-treasury))
)

;; Get total distributed
(define-read-only (get-total-distributed)
  (ok (var-get total-rewards-distributed))
)
