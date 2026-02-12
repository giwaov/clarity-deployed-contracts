;; Spinning Board Game Contract (Mainnet)
;; A game where players spin (1-10), highest spin wins
;; Min 2 players, Max 10 players per round
;; 50% to winner(s), 50% to game creator
;; Entry fee: 0.001 STX (1000 microSTX)
;; Deployer: SP31G2FZ5JN87BATZMP4ZRYE5F7WZQDNEXJ7G7X97

;; ============================================
;; Constants
;; ============================================

;; Game creator receives 50% of pot (deployer)
(define-constant GAME_CREATOR 'SP31G2FZ5JN87BATZMP4ZRYE5F7WZQDNEXJ7G7X97)

;; Entry fee: 0.001 STX = 1000 microSTX
(define-constant ENTRY_FEE u1000)

;; Players per round
(define-constant MAX_PLAYERS u10)

;; Payout percentages (in basis points, 5000 = 50%)
(define-constant WINNER_SHARE u5000)
(define-constant CREATOR_SHARE u5000)
(define-constant BASIS_POINTS u10000)

;; ============================================
;; Error Codes
;; ============================================

(define-constant ERR_ROUND_FULL (err u100))
(define-constant ERR_INVALID_SPIN (err u101))
(define-constant ERR_PAYMENT_FAILED (err u102))
(define-constant ERR_ALREADY_PLAYED (err u103))
(define-constant ERR_PAYOUT_FAILED (err u104))
(define-constant ERR_NO_WINNERS (err u105))

;; ============================================
;; Data Variables
;; ============================================

;; Current round identifier (increments after each completed round)
(define-data-var current-round uint u1)

;; Number of players in current round
(define-data-var player-count uint u0)

;; Total STX collected in current round (in microSTX)
(define-data-var total-pot uint u0)

;; Highest spin value in current round
(define-data-var highest-spin uint u0)

;; Number of players with the highest spin (for tie handling)
(define-data-var winner-count uint u0)

;; ============================================
;; Data Maps
;; ============================================

;; Tracks player spins: {round, player} -> spin value
(define-map player-spins
  { round: uint, player: principal }
  uint
)

;; Tracks if player has played in current round
(define-map has-played
  { round: uint, player: principal }
  bool
)

;; Stores winners for payout processing: {round, index} -> principal
(define-map round-winners
  { round: uint, index: uint }
  principal
)

;; Stores all players in round for winner determination: {round, index} -> {player, spin}
(define-map round-players
  { round: uint, index: uint }
  { player: principal, spin: uint }
)

;; ============================================
;; Read-Only Functions (for debugging/UI)
;; ============================================

;; Get current round number
(define-read-only (get-current-round)
  (var-get current-round)
)

;; Get current player count
(define-read-only (get-player-count)
  (var-get player-count)
)

;; Get current pot size
(define-read-only (get-total-pot)
  (var-get total-pot)
)

;; Get highest spin in current round
(define-read-only (get-highest-spin)
  (var-get highest-spin)
)

;; Get a player's spin for a specific round
(define-read-only (get-player-spin (round uint) (player principal))
  (map-get? player-spins { round: round, player: player })
)

;; Check if player has played in current round
(define-read-only (has-player-played (player principal))
  (default-to false (map-get? has-played { round: (var-get current-round), player: player }))
)

;; Get game creator address
(define-read-only (get-game-creator)
  GAME_CREATOR
)

;; Get entry fee
(define-read-only (get-entry-fee)
  ENTRY_FEE
)

;; Get player info at index for a round
(define-read-only (get-round-player (round uint) (index uint))
  (map-get? round-players { round: round, index: index })
)

;; ============================================
;; Private Functions
;; ============================================

;; Count winners with the highest spin value
(define-private (count-winners-at-spin (target-spin uint) (round uint))
  (let
    (
      (p0 (default-to { player: GAME_CREATOR, spin: u0 } (map-get? round-players { round: round, index: u0 })))
      (p1 (default-to { player: GAME_CREATOR, spin: u0 } (map-get? round-players { round: round, index: u1 })))
      (p2 (default-to { player: GAME_CREATOR, spin: u0 } (map-get? round-players { round: round, index: u2 })))
      (p3 (default-to { player: GAME_CREATOR, spin: u0 } (map-get? round-players { round: round, index: u3 })))
      (p4 (default-to { player: GAME_CREATOR, spin: u0 } (map-get? round-players { round: round, index: u4 })))
      (p5 (default-to { player: GAME_CREATOR, spin: u0 } (map-get? round-players { round: round, index: u5 })))
      (p6 (default-to { player: GAME_CREATOR, spin: u0 } (map-get? round-players { round: round, index: u6 })))
      (p7 (default-to { player: GAME_CREATOR, spin: u0 } (map-get? round-players { round: round, index: u7 })))
      (p8 (default-to { player: GAME_CREATOR, spin: u0 } (map-get? round-players { round: round, index: u8 })))
      (p9 (default-to { player: GAME_CREATOR, spin: u0 } (map-get? round-players { round: round, index: u9 })))
    )
    (+
      (if (is-eq (get spin p0) target-spin) u1 u0)
      (if (is-eq (get spin p1) target-spin) u1 u0)
      (if (is-eq (get spin p2) target-spin) u1 u0)
      (if (is-eq (get spin p3) target-spin) u1 u0)
      (if (is-eq (get spin p4) target-spin) u1 u0)
      (if (is-eq (get spin p5) target-spin) u1 u0)
      (if (is-eq (get spin p6) target-spin) u1 u0)
      (if (is-eq (get spin p7) target-spin) u1 u0)
      (if (is-eq (get spin p8) target-spin) u1 u0)
      (if (is-eq (get spin p9) target-spin) u1 u0)
    )
  )
)

;; Pay a single winner if their spin matches the target
(define-private (pay-winner-if-match (index uint) (round uint) (target-spin uint) (payout-per-winner uint))
  (let
    (
      (player-data (default-to { player: GAME_CREATOR, spin: u0 } (map-get? round-players { round: round, index: index })))
    )
    (if (is-eq (get spin player-data) target-spin)
      (as-contract (stx-transfer? payout-per-winner tx-sender (get player player-data)))
      (ok true)
    )
  )
)

;; Process all payouts for winners
(define-private (process-payouts (round uint) (target-spin uint) (total-winner-payout uint) (num-winners uint))
  (let
    (
      (payout-per-winner (/ total-winner-payout num-winners))
    )
    ;; Pay each winner
    (try! (pay-winner-if-match u0 round target-spin payout-per-winner))
    (try! (pay-winner-if-match u1 round target-spin payout-per-winner))
    (try! (pay-winner-if-match u2 round target-spin payout-per-winner))
    (try! (pay-winner-if-match u3 round target-spin payout-per-winner))
    (try! (pay-winner-if-match u4 round target-spin payout-per-winner))
    (try! (pay-winner-if-match u5 round target-spin payout-per-winner))
    (try! (pay-winner-if-match u6 round target-spin payout-per-winner))
    (try! (pay-winner-if-match u7 round target-spin payout-per-winner))
    (try! (pay-winner-if-match u8 round target-spin payout-per-winner))
    (try! (pay-winner-if-match u9 round target-spin payout-per-winner))
    (ok true)
  )
)

;; Finalize round: determine winners, distribute payouts, reset state
(define-private (finalize-round)
  (let
    (
      (round (var-get current-round))
      (pot (var-get total-pot))
      (high-spin (var-get highest-spin))
      (num-winners (count-winners-at-spin high-spin round))
      (creator-payout (/ (* pot CREATOR_SHARE) BASIS_POINTS))
      (winner-payout (/ (* pot WINNER_SHARE) BASIS_POINTS))
    )
    ;; Pay game creator their 50%
    (try! (as-contract (stx-transfer? creator-payout tx-sender GAME_CREATOR)))
    
    ;; Pay winners their split of 50%
    (if (> num-winners u0)
      (try! (process-payouts round high-spin winner-payout num-winners))
      false
    )
    
    ;; Reset state for next round
    (var-set current-round (+ round u1))
    (var-set player-count u0)
    (var-set total-pot u0)
    (var-set highest-spin u0)
    (var-set winner-count u0)
    
    (ok true)
  )
)

;; ============================================
;; Public Functions
;; ============================================

;; Main game function: player joins and spins
;; @param spin: uint between 1 and 10
(define-public (play (spin uint))
  (let
    (
      (player tx-sender)
      (round (var-get current-round))
      (count (var-get player-count))
    )
    ;; Validate round is not full
    (asserts! (< count MAX_PLAYERS) ERR_ROUND_FULL)
    
    ;; Validate spin value (1-10)
    (asserts! (and (>= spin u1) (<= spin u10)) ERR_INVALID_SPIN)
    
    ;; Validate player hasn't already played this round
    (asserts! (not (has-player-played player)) ERR_ALREADY_PLAYED)
    
    ;; Transfer entry fee from player to contract
    (try! (stx-transfer? ENTRY_FEE player (as-contract tx-sender)))
    
    ;; Record player's spin
    (map-set player-spins { round: round, player: player } spin)
    (map-set has-played { round: round, player: player } true)
    (map-set round-players { round: round, index: count } { player: player, spin: spin })
    
    ;; Update highest spin if necessary
    (if (> spin (var-get highest-spin))
      (var-set highest-spin spin)
      false
    )
    
    ;; Update state
    (var-set player-count (+ count u1))
    (var-set total-pot (+ (var-get total-pot) ENTRY_FEE))
    
    ;; If this is the 10th player, finalize the round
    (if (is-eq (+ count u1) MAX_PLAYERS)
      (begin
        (try! (finalize-round))
        (ok { status: "round-complete", round: round, spin: spin })
      )
      (ok { status: "joined", round: round, spin: spin })
    )
  )
)
