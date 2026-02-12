;; WIN CHECKER CONTRACT
;; Validates win conditions and calculates scores

;; ============================================================================
;; CONSTANTS
;; ============================================================================

(define-constant ERR_GAME_NOT_FOUND (err u300))
(define-constant ERR_GAME_NOT_FINISHED (err u301))
(define-constant ERR_NOT_AUTHORIZED (err u302))

(define-constant BASE_SCORE u1000)
(define-constant MAX_TIME_BONUS u500)

;; ============================================================================
;; WIN CONDITION CHECK
;; ============================================================================

;; Check if player has won (all safe cells revealed)
(define-public (check-win-condition (game-id uint))
  (let
    (
      ;; Get game information
      (game (unwrap! (contract-call? .game-core-02 get-game-info game-id) ERR_GAME_NOT_FOUND))
      ;; Get game statistics
      (stats (unwrap! (contract-call? .game-core-02 get-game-stats game-id) ERR_GAME_NOT_FOUND))
      (cells-revealed (get cells-revealed stats))
      (safe-cells (get safe-cells stats))
    )
    ;; Check if all safe cells are revealed
    (if (is-eq cells-revealed safe-cells)
      (let
        (
          (final-score (unwrap-panic (calculate-score game-id)))
        )
        ;; Mark game as won in game-core
        (try! (contract-call? .game-core-02 mark-game-won game-id final-score))
        
        ;; Update player statistics
        (try! (contract-call? .player-profile-02 update-win-stats (get player game) game-id (get difficulty game)))
        ;; Submit score to leaderboard
        (try! (contract-call? .leaderboard-02 submit-score game-id (get player game) (get difficulty game) final-score))
        ;; Calculate and award rewards
        (try! (contract-call? .economy-02 calculate-rewards game-id))
        
        (print {event: "check-win-condition", game-id: game-id, won: true, final-score: final-score})
        (ok true)
      )
      (begin
        (print {event: "check-win-condition", game-id: game-id, won: false})
        (ok false)
      )
    )
  )
)

;; ============================================================================
;; SCORE CALCULATION
;; ============================================================================

;; Calculate final score
(define-public (calculate-score (game-id uint))
  (let
    (
      ;; Get game information
      (game (unwrap! (contract-call? .game-core-02 get-game-info game-id) ERR_GAME_NOT_FOUND))
      ;; Get game statistics
      (stats (unwrap! (contract-call? .game-core-02 get-game-stats game-id) ERR_GAME_NOT_FOUND))
      (time-elapsed (default-to u0 (get final-time game)))
      (difficulty (get difficulty game))
      
      ;; Base score
      (base BASE_SCORE)
      
      ;; Time bonus (max 500, decreases with time)
      (time-bonus (if (< time-elapsed MAX_TIME_BONUS)
        (- MAX_TIME_BONUS time-elapsed)
        u0
      ))
      
      ;; Efficiency (fewer moves = better)
      (efficiency-score (calculate-efficiency stats))
      
      ;; Flag accuracy
      (flag-accuracy (calculate-flag-accuracy stats))
      
      ;; Difficulty multiplier
      (multiplier (get-difficulty-multiplier difficulty))
      
      ;; Total before multiplier
      (subtotal (+ (+ (+ base time-bonus) efficiency-score) flag-accuracy))
      
      ;; Final score
      (final (* subtotal multiplier))
    )
    (print {event: "calculate-score", game-id: game-id, score: final, difficulty: difficulty})
    (ok final)
  )
)

;; Calculate efficiency score
(define-private (calculate-efficiency (stats (tuple 
  (moves-count uint)
  (flags-placed uint)
  (flags-correct uint)
  (cells-revealed uint)
  (cells-total uint)
  (safe-cells uint)
)))
  (let
    (
      (cells-revealed (get cells-revealed stats))
      (moves-count (get moves-count stats))
    )
    ;; Perfect efficiency = revealed cells / moves close to 1
    ;; Score: (safe-cells / moves) * 100
    (if (> moves-count u0)
      (* (/ cells-revealed moves-count) u100)
      u0
    )
  )
)

;; Calculate flag accuracy score
(define-private (calculate-flag-accuracy (stats (tuple 
  (moves-count uint)
  (flags-placed uint)
  (flags-correct uint)
  (cells-revealed uint)
  (cells-total uint)
  (safe-cells uint)
)))
  (let
    (
      (flags-placed (get flags-placed stats))
      (flags-correct (get flags-correct stats))
    )
    ;; Accuracy: (correct / placed) * 50
    (if (> flags-placed u0)
      (* (/ (* flags-correct u100) flags-placed) u50)
      u0
    )
  )
)

;; Get difficulty multiplier
(define-private (get-difficulty-multiplier (difficulty uint))
  (if (is-eq difficulty u1)
    u1 ;; Beginner
    (if (is-eq difficulty u2)
      u2 ;; Intermediate
      u4 ;; Expert
    )
  )
)

;; ============================================================================
;; READ-ONLY FUNCTIONS
;; ============================================================================

;; Preview score before game ends
(define-read-only (preview-score (game-id uint))
  (calculate-score game-id)
)

;; Check if game is won
(define-read-only (is-game-won (game-id uint))
  ;; Get game status from game-core
  (match (contract-call? .game-core-02 get-game-info game-id)
    game (is-eq (get status game) "won")
    false
  )
)
