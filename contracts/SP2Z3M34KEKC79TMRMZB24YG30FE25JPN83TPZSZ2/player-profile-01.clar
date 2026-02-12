;; PLAYER PROFILE CONTRACT - Stats + Streaks (merged)
;; Comprehensive player statistics and streak tracking

;; ============================================================================
;; CONSTANTS
;; ============================================================================

(define-constant ERR_NOT_FOUND (err u500))
(define-constant ERR_NOT_AUTHORIZED (err u501))

;; ============================================================================
;; DATA MAPS
;; ============================================================================

;; Player statistics
(define-map player-stats
  { player: principal }
  {
    total-games: uint,
    total-wins: uint,
    total-losses: uint,
    
    ;; Per difficulty
    beginner-wins: uint,
    beginner-losses: uint,
    beginner-best-time: uint,
    
    intermediate-wins: uint,
    intermediate-losses: uint,
    intermediate-best-time: uint,
    
    expert-wins: uint,
    expert-losses: uint,
    expert-best-time: uint,
    
    ;; Accuracy
    total-moves: uint,
    total-flags-placed: uint,
    total-flags-correct: uint,
    
    ;; Timestamps
    first-game-at: uint,
    last-game-at: uint,
    total-playtime: uint
  }
)

;; Player streaks
(define-map player-streaks
  { player: principal }
  {
    ;; Win streaks
    current-win-streak: uint,
    best-win-streak: uint,
    win-streak-started-at: uint,
    
    ;; Daily login
    current-login-streak: uint,
    best-login-streak: uint,
    last-login-date: uint, ;; stacks-block-height
    
    ;; Perfect game streak
    current-perfect-streak: uint,
    best-perfect-streak: uint,
    
    ;; Streak savers
    streak-savers-available: uint,
    last-streak-saver-earned: uint
  }
)

;; ============================================================================
;; UPDATE STATS
;; ============================================================================

;; Update stats after game completion
(define-public (update-win-stats 
  (player principal)
  (game-id uint)
  (difficulty uint))
  (let
    (
      ;; Get game info from game-core contract
      (game (unwrap! (contract-call? .game-core-01 get-game-info game-id) ERR_NOT_FOUND))
      ;; Get game statistics
      (stats (unwrap! (contract-call? .game-core-01 get-game-stats game-id) ERR_NOT_FOUND))
      (current-stats (default-to (get-default-stats player) (map-get? player-stats {player: player})))
      (time (default-to u0 (get final-time game)))
      (won (is-eq (get status game) "won"))
    )
    ;; Update general stats
    (map-set player-stats
      {player: player}
      (merge current-stats {
        total-games: (+ (get total-games current-stats) u1),
        total-wins: (if won (+ (get total-wins current-stats) u1) (get total-wins current-stats)),
        total-losses: (if won (get total-losses current-stats) (+ (get total-losses current-stats) u1)),
        last-game-at: stacks-block-height,
        total-moves: (+ (get total-moves current-stats) (get moves-count stats)),
        total-flags-placed: (+ (get total-flags-placed current-stats) (get flags-placed stats)),
        total-playtime: (+ (get total-playtime current-stats) time)
      })
    )
    
    ;; Update difficulty-specific stats and streaks
    (begin
      (let ((dummy (if (is-eq difficulty u1)
                      (update-beginner-stats player won time)
                      (if (is-eq difficulty u2)
                        (update-intermediate-stats player won time)
                        (update-expert-stats player won time)
                      ))))
        (update-win-streak player won)
      )
    )
  )
)

;; Update beginner stats
(define-private (update-beginner-stats (player principal) (won bool) (time uint))
  (let
    (
      (current-stats (default-to (get-default-stats player) (map-get? player-stats {player: player})))
    )
    (map-set player-stats
      {player: player}
      (merge current-stats {
        beginner-wins: (if won (+ (get beginner-wins current-stats) u1) (get beginner-wins current-stats)),
        beginner-losses: (if won (get beginner-losses current-stats) (+ (get beginner-losses current-stats) u1)),
        beginner-best-time: (if (and won (or (is-eq (get beginner-best-time current-stats) u0) 
                                             (< time (get beginner-best-time current-stats))))
          time
          (get beginner-best-time current-stats)
        )
      })
    )
    true
  )
)

;; Update intermediate stats
(define-private (update-intermediate-stats (player principal) (won bool) (time uint))
  (let
    (
      (current-stats (default-to (get-default-stats player) (map-get? player-stats {player: player})))
    )
    (map-set player-stats
      {player: player}
      (merge current-stats {
        intermediate-wins: (if won (+ (get intermediate-wins current-stats) u1) (get intermediate-wins current-stats)),
        intermediate-losses: (if won (get intermediate-losses current-stats) (+ (get intermediate-losses current-stats) u1)),
        intermediate-best-time: (if (and won (or (is-eq (get intermediate-best-time current-stats) u0) 
                                                 (< time (get intermediate-best-time current-stats))))
          time
          (get intermediate-best-time current-stats)
        )
      })
    )
    true
  )
)

;; Update expert stats
(define-private (update-expert-stats (player principal) (won bool) (time uint))
  (let
    (
      (current-stats (default-to (get-default-stats player) (map-get? player-stats {player: player})))
    )
    (map-set player-stats
      {player: player}
      (merge current-stats {
        expert-wins: (if won (+ (get expert-wins current-stats) u1) (get expert-wins current-stats)),
        expert-losses: (if won (get expert-losses current-stats) (+ (get expert-losses current-stats) u1)),
        expert-best-time: (if (and won (or (is-eq (get expert-best-time current-stats) u0) 
                                           (< time (get expert-best-time current-stats))))
          time
          (get expert-best-time current-stats)
        )
      })
    )
    true
  )
)

;; ============================================================================
;; STREAK MANAGEMENT
;; ============================================================================

;; Update win streak
(define-public (update-win-streak (player principal) (won bool))
  (let
    (
      (current-streaks (default-to (get-default-streaks) (map-get? player-streaks {player: player})))
      (current-streak (get current-win-streak current-streaks))
      (best-streak (get best-win-streak current-streaks))
      (savers-available (get streak-savers-available current-streaks))
    )
    (begin
      (if won
        ;; Won - increment streak
        (let
          (
            (new-streak (+ current-streak u1))
            (new-best (if (> new-streak best-streak) new-streak best-streak))
          )
          (map-set player-streaks
            {player: player}
            (merge current-streaks {
              current-win-streak: new-streak,
              best-win-streak: new-best,
              win-streak-started-at: (if (is-eq current-streak u0) stacks-block-height (get win-streak-started-at current-streaks))
            })
          )
          ;; Award streak saver every 30 wins
          (if (is-eq (mod new-streak u30) u0)
            (map-set player-streaks
              {player: player}
              (merge current-streaks {
                streak-savers-available: (+ savers-available u1),
                last-streak-saver-earned: stacks-block-height
              })
            )
            true
          )
        )
        ;; Lost - check for streak saver
        (if (> savers-available u0)
          ;; Use streak saver
          (begin
            (map-set player-streaks
              {player: player}
              (merge current-streaks {
                streak-savers-available: (- savers-available u1)
              })
            )
            (print "Streak Saver used! Streak protected.")
            true
          )
          ;; No saver - reset streak
          (begin
            (map-set player-streaks
              {player: player}
              (merge current-streaks {
                current-win-streak: u0
              })
            )
            true
          )
        )
      )
      (ok true)
    )
  )
)

;; Check daily login (updates streak)
(define-public (check-daily-login (player principal))
  (let
    (
      (current-streaks (default-to (get-default-streaks) (map-get? player-streaks {player: player})))
      (last-login (get last-login-date current-streaks))
      (blocks-per-day u144) ;; ~10 min blocks = 144 per day
      (blocks-since-last (- stacks-block-height last-login))
    )
    (if (<= blocks-since-last blocks-per-day)
      ;; Same day or next day - increment
      (map-set player-streaks
        {player: player}
        (merge current-streaks {
          current-login-streak: (+ (get current-login-streak current-streaks) u1),
          best-login-streak: (max (+ (get current-login-streak current-streaks) u1) (get best-login-streak current-streaks)),
          last-login-date: stacks-block-height
        })
      )
      ;; Missed a day - reset
      (map-set player-streaks
        {player: player}
        (merge current-streaks {
          current-login-streak: u1,
          last-login-date: stacks-block-height
        })
      )
    )
    (ok true)
  )
)

;; ============================================================================
;; READ-ONLY FUNCTIONS
;; ============================================================================

;; Get player stats
(define-read-only (get-player-stats (player principal))
  (ok (map-get? player-stats {player: player}))
)

;; Get player streaks
(define-read-only (get-player-streaks (player principal))
  (ok (map-get? player-streaks {player: player}))
)

;; Calculate win rate
(define-read-only (calculate-win-rate (player principal))
  (match (map-get? player-stats {player: player})
    stats (if (> (get total-games stats) u0)
      (ok (/ (* (get total-wins stats) u100) (get total-games stats)))
      (ok u0)
    )
    (ok u0)
  )
)

;; Get streak multiplier
(define-read-only (get-streak-multiplier (player principal))
  (match (map-get? player-streaks {player: player})
    streaks (let ((streak (get current-win-streak streaks)))
      (if (>= streak u100) u5
        (if (>= streak u50) u3
          (if (>= streak u25) u2
            (if (>= streak u10) u1
              (if (>= streak u5) u1
                u1
              )
            )
          )
        )
      )
    )
    u1
  )
)

;; ============================================================================
;; HELPERS
;; ============================================================================

(define-private (get-default-stats (player principal))
  {
    total-games: u0,
    total-wins: u0,
    total-losses: u0,
    beginner-wins: u0,
    beginner-losses: u0,
    beginner-best-time: u0,
    intermediate-wins: u0,
    intermediate-losses: u0,
    intermediate-best-time: u0,
    expert-wins: u0,
    expert-losses: u0,
    expert-best-time: u0,
    total-moves: u0,
    total-flags-placed: u0,
    total-flags-correct: u0,
    first-game-at: stacks-block-height,
    last-game-at: stacks-block-height,
    total-playtime: u0
  }
)

(define-private (get-default-streaks)
  {
    current-win-streak: u0,
    best-win-streak: u0,
    win-streak-started-at: u0,
    current-login-streak: u0,
    best-login-streak: u0,
    last-login-date: u0,
    current-perfect-streak: u0,
    best-perfect-streak: u0,
    streak-savers-available: u0,
    last-streak-saver-earned: u0
  }
)

(define-private (max (a uint) (b uint))
  (if (> a b) a b)
)
