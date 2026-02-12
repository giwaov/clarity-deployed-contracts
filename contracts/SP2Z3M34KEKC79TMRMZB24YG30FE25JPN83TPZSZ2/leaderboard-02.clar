;; LEADERBOARD CONTRACT
;; Global rankings per difficulty level

;; ============================================================================
;; CONSTANTS
;; ============================================================================

(define-constant ERR_NOT_FOUND (err u400))
(define-constant MAX_LEADERBOARD_SIZE u100)

;; ============================================================================
;; DATA MAPS
;; ============================================================================

;; Leaderboard entries (per difficulty)
(define-map leaderboard-entries
  { difficulty: uint, rank: uint }
  {
    player: principal,
    score: uint,
    time: uint,
    game-id: uint,
    achieved-at: uint
  }
)

;; Player best scores
(define-map player-best-scores
  { player: principal, difficulty: uint }
  {
    best-score: uint,
    best-time: uint,
    best-game-id: uint,
    current-rank: uint
  }
)

;; World records
(define-map world-records
  { difficulty: uint }
  {
    player: principal,
    time: uint,
    score: uint,
    game-id: uint,
    set-at: uint
  }
)

;; Leaderboard size tracker
(define-map leaderboard-sizes
  { difficulty: uint }
  { size: uint }
)

;; ============================================================================
;; SUBMIT SCORE
;; ============================================================================

(define-public (submit-score 
  (game-id uint)
  (player principal)
  (difficulty uint)
  (score uint))
  (let
    (
      ;; Get game info from game-core
      (game (unwrap! (contract-call? .game-core-02 get-game-info game-id) ERR_NOT_FOUND))
      (time (default-to u0 (get final-time game)))
      (current-size (default-to u0 (get size (map-get? leaderboard-sizes {difficulty: difficulty}))))
      (player-best (map-get? player-best-scores {player: player, difficulty: difficulty}))
    )
    ;; Update player best if better
    (match player-best
      existing-best (if (or (> score (get best-score existing-best)) 
                            (and (is-eq score (get best-score existing-best)) 
                                 (< time (get best-time existing-best))))
        (map-set player-best-scores
          {player: player, difficulty: difficulty}
          {
            best-score: score,
            best-time: time,
            best-game-id: game-id,
            current-rank: u0 ;; Will be calculated
          }
        )
        true
      )
      ;; First score for this player/difficulty
      (map-set player-best-scores
        {player: player, difficulty: difficulty}
        {
          best-score: score,
          best-time: time,
          best-game-id: game-id,
          current-rank: u0
        }
      )
    )
    
    ;; Check world record
    (try! (check-world-record difficulty player score time game-id))
    
    (print {event: "submit-score", game-id: game-id, player: player, difficulty: difficulty, score: score, time: time})
    (ok true)
  )
)

;; ============================================================================
;; WORLD RECORDS
;; ============================================================================

(define-private (check-world-record 
  (difficulty uint)
  (player principal)
  (score uint)
  (time uint)
  (game-id uint))
  (let
    (
      (current-wr (map-get? world-records {difficulty: difficulty}))
    )
    (match current-wr
      existing-wr (if (< time (get time existing-wr))
        (begin
          (map-set world-records
            {difficulty: difficulty}
            {
              player: player,
              time: time,
              score: score,
              game-id: game-id,
              set-at: stacks-block-height
            }
          )
          ;; Award world record achievement
          (try! (contract-call? .achievement-nft-02 award-achievement player u12))
          (ok true)
        )
        (ok false)
      )
      ;; First world record
      (begin
        (map-set world-records
          {difficulty: difficulty}
          {
            player: player,
            time: time,
            score: score,
            game-id: game-id,
            set-at: stacks-block-height
          }
        )
        (ok true)
      )
    )
  )
)

;; ============================================================================
;; READ-ONLY FUNCTIONS
;; ============================================================================

;; Get leaderboard (top N)
(define-read-only (get-leaderboard (difficulty uint) (limit uint))
  ;; In production, would fetch sorted list
  ;; For now, return placeholder
  (ok (list))
)

;; Get player rank
(define-read-only (get-player-rank (player principal) (difficulty uint))
  (match (map-get? player-best-scores {player: player, difficulty: difficulty})
    best-score (ok (get current-rank best-score))
    ERR_NOT_FOUND
  )
)

;; Get world record
(define-read-only (get-world-record (difficulty uint))
  (ok (map-get? world-records {difficulty: difficulty}))
)

;; Get player best
(define-read-only (get-player-best (player principal) (difficulty uint))
  (ok (map-get? player-best-scores {player: player, difficulty: difficulty}))
)
