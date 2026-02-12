;; DAILY CHALLENGE CONTRACT
;; One shared board per day for all players

;; ============================================================================
;; CONSTANTS
;; ============================================================================

(define-constant ERR_NOT_FOUND (err u1000))
(define-constant ERR_ALREADY_COMPLETED (err u1001))
(define-constant ERR_REWARD_CLAIMED (err u1002))
(define-constant ERR_NOT_AUTHORIZED (err u1003))

(define-constant BLOCKS_PER_DAY u144) ;; ~10 min blocks
(define-constant BASE_DAILY_REWARD u10)

;; ============================================================================
;; DATA VARS
;; ============================================================================

(define-data-var current-challenge-id uint u0)
(define-data-var last-challenge-date uint u0)

;; ============================================================================
;; DATA MAPS
;; ============================================================================

(define-map daily-challenges
  { challenge-id: uint }
  {
    date: uint, ;; stacks-block-height
    difficulty: uint,
    board-seed: (buff 32),
    total-completions: uint,
    fastest-time: (optional uint),
    fastest-player: (optional principal),
    highest-score: (optional uint),
    highest-score-player: (optional principal)
  }
)

(define-map daily-completions
  { challenge-id: uint, player: principal }
  {
    game-id: uint,
    time: uint,
    score: uint,
    rank: uint,
    completed-at: uint,
    reward-claimed: bool
  }
)

(define-map player-daily-streaks
  { player: principal }
  {
    current-streak: uint,
    longest-streak: uint,
    last-completion-date: uint,
    total-dailies-completed: uint
  }
)

;; ============================================================================
;; CHALLENGE GENERATION
;; ============================================================================

;; Generate today's challenge (called automatically or by admin)
(define-public (generate-daily-challenge)
  (let
    (
      (last-date (var-get last-challenge-date))
      (blocks-since (- stacks-block-height last-date))
    )
    ;; Check if enough time passed (1 day)
    (asserts! (>= blocks-since BLOCKS_PER_DAY) ERR_NOT_AUTHORIZED)
    
    (let
      (
        (new-id (+ (var-get current-challenge-id) u1))
        ;; Pseudo-random difficulty (weighted)
        (random-val (mod stacks-block-height u10))
        (difficulty (if (< random-val u4) u1 (if (< random-val u8) u2 u3)))
        ;; Generate seed
        (seed (sha256 (concat
          (unwrap-panic (to-consensus-buff? new-id))
          (unwrap-panic (to-consensus-buff? stacks-block-height))
        )))
      )
      ;; Create challenge
      (map-set daily-challenges
        {challenge-id: new-id}
        {
          date: stacks-block-height,
          difficulty: difficulty,
          board-seed: seed,
          total-completions: u0,
          fastest-time: none,
          fastest-player: none,
          highest-score: none,
          highest-score-player: none
        }
      )
      
      ;; Update vars
      (var-set current-challenge-id new-id)
      (var-set last-challenge-date stacks-block-height)
      
      (ok new-id)
    )
  )
)

;; ============================================================================
;; CHALLENGE COMPLETION
;; ============================================================================

;; Submit daily challenge completion
(define-public (complete-daily-challenge (challenge-id uint) (game-id uint))
  (let
    (
      (challenge (unwrap! (map-get? daily-challenges {challenge-id: challenge-id}) ERR_NOT_FOUND))
      ;; Get game information
      (game (unwrap! (contract-call? .game-core-01 get-game-info game-id) ERR_NOT_FOUND))
      (player (get player game))
      (time (default-to u0 (get final-time game)))
      (score (default-to u0 (get final-score game)))
      (existing (map-get? daily-completions {challenge-id: challenge-id, player: player}))
    )
    ;; Validate
    (asserts! (is-eq player tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status game) "won") ERR_NOT_AUTHORIZED)
    (asserts! (is-none existing) ERR_ALREADY_COMPLETED)
    
    ;; Record completion
    (map-set daily-completions
      {challenge-id: challenge-id, player: player}
      {
        game-id: game-id,
        time: time,
        score: score,
        rank: u0, ;; Will be calculated
        completed-at: stacks-block-height,
        reward-claimed: false
      }
    )
    
    ;; Update challenge stats
    (let
      (
        (new-completions (+ (get total-completions challenge) u1))
        (is-fastest (or 
          (is-none (get fastest-time challenge))
          (< time (unwrap-panic (get fastest-time challenge)))
        ))
        (is-highest-score (or
          (is-none (get highest-score challenge))
          (> score (unwrap-panic (get highest-score challenge)))
        ))
      )
      (map-set daily-challenges
        {challenge-id: challenge-id}
        (merge challenge {
          total-completions: new-completions,
          fastest-time: (if is-fastest (some time) (get fastest-time challenge)),
          fastest-player: (if is-fastest (some player) (get fastest-player challenge)),
          highest-score: (if is-highest-score (some score) (get highest-score challenge)),
          highest-score-player: (if is-highest-score (some player) (get highest-score-player challenge))
        })
      )
    )
    
    ;; Update player streak
    (unwrap-panic (update-daily-streak player))
    
    (ok true)
  )
)

;; ============================================================================
;; STREAK MANAGEMENT
;; ============================================================================

(define-private (update-daily-streak (player principal))
  (let
    (
      (current-streak-data (default-to 
        {current-streak: u0, longest-streak: u0, last-completion-date: u0, total-dailies-completed: u0}
        (map-get? player-daily-streaks {player: player})
      ))
      (last-date (get last-completion-date current-streak-data))
      (blocks-since (- stacks-block-height last-date))
    )
    (if (<= blocks-since (* BLOCKS_PER_DAY u2)) ;; Within 2 days = streak continues
      (let
        (
          (new-streak (+ (get current-streak current-streak-data) u1))
        )
        (map-set player-daily-streaks
          {player: player}
          {
            current-streak: new-streak,
            longest-streak: (max new-streak (get longest-streak current-streak-data)),
            last-completion-date: stacks-block-height,
            total-dailies-completed: (+ (get total-dailies-completed current-streak-data) u1)
          }
        )
        
        ;; Award achievement for 30-day streak
        (begin
          (and (is-eq new-streak u30)
               (is-ok (contract-call? .achievement-nft-01 award-achievement player u15)))
          (ok true)
        )
      )
      ;; Streak broken - reset
      (begin
        (map-set player-daily-streaks
          {player: player}
          {
            current-streak: u1,
            longest-streak: (get longest-streak current-streak-data),
            last-completion-date: stacks-block-height,
            total-dailies-completed: (+ (get total-dailies-completed current-streak-data) u1)
          }
        )
        (ok true)
      )
    )
  )
)

;; ============================================================================
;; REWARD CLAIMING
;; ============================================================================

(define-public (claim-daily-reward (challenge-id uint))
  (let
    (
      (completion (unwrap! (map-get? daily-completions {challenge-id: challenge-id, player: tx-sender}) ERR_NOT_FOUND))
      (challenge (unwrap! (map-get? daily-challenges {challenge-id: challenge-id}) ERR_NOT_FOUND))
    )
    ;; Validate not already claimed
    (asserts! (not (get reward-claimed completion)) ERR_REWARD_CLAIMED)
    
    ;; Calculate reward
    (let
      (
        (base BASE_DAILY_REWARD)
        ;; Bonus for top 10
        (rank-bonus (if (< (get rank completion) u10)
          (- u100 (* (get rank completion) u10))
          u0
        ))
        ;; Streak bonus
        (streak-data (default-to 
          {current-streak: u0, longest-streak: u0, last-completion-date: u0, total-dailies-completed: u0}
          (map-get? player-daily-streaks {player: tx-sender})
        ))
        (streak-bonus (if (>= (get current-streak streak-data) u7) u50 u0))
        
        (total-reward (+ (+ base rank-bonus) streak-bonus))
      )
      ;; Mark as claimed
      (map-set daily-completions
        {challenge-id: challenge-id, player: tx-sender}
        (merge completion {reward-claimed: true})
      )
      
      ;; Add rewards via economy contract
      (unwrap-panic (contract-call? .economy-01 add-rewards tx-sender total-reward u0))
      
      (ok total-reward)
    )
  )
)

;; ============================================================================
;; READ-ONLY FUNCTIONS
;; ============================================================================

(define-read-only (get-current-challenge)
  (let
    (
      (challenge-id (var-get current-challenge-id))
    )
    (ok (map-get? daily-challenges {challenge-id: challenge-id}))
  )
)

(define-read-only (get-challenge-info (challenge-id uint))
  (ok (map-get? daily-challenges {challenge-id: challenge-id}))
)

(define-read-only (get-player-completion (challenge-id uint) (player principal))
  (ok (map-get? daily-completions {challenge-id: challenge-id, player: player}))
)

(define-read-only (get-player-streak (player principal))
  (ok (map-get? player-daily-streaks {player: player}))
)

;; Get daily leaderboard (top 10)
(define-read-only (get-daily-leaderboard (challenge-id uint))
  ;; In production, would return sorted list
  (ok (list))
)

;; ============================================================================
;; HELPERS
;; ============================================================================

(define-private (max (a uint) (b uint))
  (if (> a b) a b)
)
