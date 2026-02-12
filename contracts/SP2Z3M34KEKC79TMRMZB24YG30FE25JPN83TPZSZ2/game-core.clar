;; GAME CORE CONTRACT - Game Factory + State + Move Validator (merged for gas optimization)
;; Handles game creation, state management, and move validation

;; ============================================================================
;; CONSTANTS
;; ============================================================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_GAME_NOT_FOUND (err u101))
(define-constant ERR_INVALID_DIFFICULTY (err u102))
(define-constant ERR_GAME_ALREADY_FINISHED (err u103))
(define-constant ERR_INVALID_MOVE (err u104))
(define-constant ERR_CELL_ALREADY_REVEALED (err u105))
(define-constant ERR_CELL_FLAGGED (err u106))
(define-constant ERR_OUT_OF_BOUNDS (err u107))
(define-constant ERR_GAME_PAUSED (err u108))

(define-constant DIFFICULTY_BEGINNER u1)
(define-constant DIFFICULTY_INTERMEDIATE u2)
(define-constant DIFFICULTY_EXPERT u3)

(define-constant STATUS_IN_PROGRESS "in-progress")
(define-constant STATUS_WON "won")
(define-constant STATUS_LOST "lost")

;; ============================================================================
;; DATA VARS
;; ============================================================================

(define-data-var game-id-nonce uint u0)
(define-data-var contract-paused bool false)

;; ============================================================================
;; DATA MAPS
;; ============================================================================

;; Main game data
(define-map games
  { game-id: uint }
  {
    player: principal,
    difficulty: uint,
    board-size-x: uint,
    board-size-y: uint,
    mine-count: uint,
    status: (string-ascii 20),
    created-at: uint,
    started-at: (optional uint),
    finished-at: (optional uint),
    final-time: (optional uint),
    final-score: (optional uint)
  }
)

;; Game statistics
(define-map game-stats
  { game-id: uint }
  {
    moves-count: uint,
    flags-placed: uint,
    flags-correct: uint,
    cells-revealed: uint,
    cells-total: uint,
    safe-cells: uint
  }
)

;; Revealed cells (bitpacked storage - only store revealed cells)
;; Each cell stores: revealed (bool), is-mine (bool), adjacent-mines (uint 0-8)
(define-map revealed-cells
  { game-id: uint, cell-index: uint }
  {
    is-mine: bool,
    adjacent-mines: uint,
    revealed-at: uint
  }
)

;; Flagged cells (separate map for gas optimization)
(define-map flagged-cells
  { game-id: uint, cell-index: uint }
  { flagged: bool }
)

;; ============================================================================
;; HELPER FUNCTIONS
;; ============================================================================

;; Convert (x, y) coordinates to cell index
(define-read-only (coords-to-index (x uint) (y uint) (width uint))
  (+ (* y width) x)
)

;; Convert cell index to (x, y) coordinates
(define-read-only (index-to-coords (index uint) (width uint))
  {
    x: (mod index width),
    y: (/ index width)
  }
)

;; Get board dimensions for difficulty
(define-read-only (get-board-dimensions (difficulty uint))
  (if (is-eq difficulty DIFFICULTY_BEGINNER)
    { width: u9, height: u9, mines: u10 }
    (if (is-eq difficulty DIFFICULTY_INTERMEDIATE)
      { width: u16, height: u16, mines: u40 }
      { width: u30, height: u16, mines: u99 } ;; Expert
    )
  )
)

;; Check if coordinates are in bounds
(define-read-only (is-in-bounds (x uint) (y uint) (width uint) (height uint))
  (and
    (< x width)
    (< y height)
  )
)

;; Get cell index from coordinates with bounds check
(define-private (get-cell-index (game-id uint) (x uint) (y uint))
  (let
    (
      (game (unwrap! (map-get? games { game-id: game-id }) (err u0)))
      (width (get board-size-x game))
      (height (get board-size-y game))
    )
    (if (is-in-bounds x y width height)
      (ok (coords-to-index x y width))
      (err u0)
    )
  )
)

;; ============================================================================
;; GAME CREATION
;; ============================================================================

;; Create new game
(define-public (create-game (difficulty uint))
  (let
    (
      (game-id (+ (var-get game-id-nonce) u1))
      (dims (get-board-dimensions difficulty))
      (total-cells (* (get width dims) (get height dims)))
      (safe-cells (- total-cells (get mines dims)))
    )
    ;; Validate difficulty
    (asserts! (or
      (is-eq difficulty DIFFICULTY_BEGINNER)
      (is-eq difficulty DIFFICULTY_INTERMEDIATE)
      (is-eq difficulty DIFFICULTY_EXPERT)
    ) ERR_INVALID_DIFFICULTY)
    
    ;; Validate not paused
    (asserts! (not (var-get contract-paused)) ERR_GAME_PAUSED)
    
    ;; Create game
    (map-set games
      { game-id: game-id }
      {
        player: tx-sender,
        difficulty: difficulty,
        board-size-x: (get width dims),
        board-size-y: (get height dims),
        mine-count: (get mines dims),
        status: STATUS_IN_PROGRESS,
        created-at: stacks-block-height,
        started-at: none,
        finished-at: none,
        final-time: none,
        final-score: none
      }
    )
    
    ;; Initialize stats
    (map-set game-stats
      { game-id: game-id }
      {
        moves-count: u0,
        flags-placed: u0,
        flags-correct: u0,
        cells-revealed: u0,
        cells-total: total-cells,
        safe-cells: safe-cells
      }
    )
    
    ;; Increment nonce
    (var-set game-id-nonce game-id)
    
    ;; Call board generator (will be handled by board-generator contract)
    ;; For now, just return game-id
    (print {event: "create-game", game-id: game-id, player: tx-sender})
    (ok game-id)
  )
)

;; ============================================================================
;; MOVE VALIDATION & EXECUTION
;; ============================================================================

;; Reveal single cell (left click)
(define-public (reveal-cell (game-id uint) (x uint) (y uint))
  (let
    (
      (game (unwrap! (map-get? games { game-id: game-id }) ERR_GAME_NOT_FOUND))
      (stats (unwrap! (map-get? game-stats { game-id: game-id }) ERR_GAME_NOT_FOUND))
      (cell-index (unwrap! (get-cell-index game-id x y) ERR_OUT_OF_BOUNDS))
    )
    ;; Validate
    (asserts! (is-eq (get player game) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status game) STATUS_IN_PROGRESS) ERR_GAME_ALREADY_FINISHED)
    (asserts! (is-none (map-get? revealed-cells { game-id: game-id, cell-index: cell-index })) ERR_CELL_ALREADY_REVEALED)
    (asserts! (is-none (map-get? flagged-cells { game-id: game-id, cell-index: cell-index })) ERR_CELL_FLAGGED)
    
    ;; Start timer on first move and proceed with reveal
    (begin
      (if (is-none (get started-at game))
        (map-set games
          { game-id: game-id }
          (merge game { started-at: (some stacks-block-height) })
        )
        false
      )
      
      ;; This will interact with board-generator to check if mine
      ;; For now, return ok - actual implementation will check mine status
      (print {event: "reveal-cell", game-id: game-id, x: x, y: y, player: tx-sender})
      (ok true)
    )
  )
)

;; Batch reveal cells (optimized for flood fill)
;; Frontend computes flood fill off-chain, submits batch
(define-public (reveal-cells-batch (game-id uint) (cell-indices (list 50 uint)) (adjacent-mines-list (list 50 uint)))
  (let
    (
      (game (unwrap! (map-get? games { game-id: game-id }) ERR_GAME_NOT_FOUND))
      (stats (unwrap! (map-get? game-stats { game-id: game-id }) ERR_GAME_NOT_FOUND))
    )
    ;; Validate
    (asserts! (is-eq (get player game) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status game) STATUS_IN_PROGRESS) ERR_GAME_ALREADY_FINISHED)
    
    ;; Start timer on first move and process batch
    (begin
      (if (is-none (get started-at game))
        (map-set games
          { game-id: game-id }
          (merge game { started-at: (some stacks-block-height) })
        )
        false
      )
      
      ;; Process batch (will verify with board-generator)
      ;; Update revealed cells count
      (map-set game-stats
        { game-id: game-id }
        (merge stats {
          cells-revealed: (+ (get cells-revealed stats) (len cell-indices)),
          moves-count: (+ (get moves-count stats) u1)
        })
      )
      
      (print {event: "reveal-cells-batch", game-id: game-id, player: tx-sender})
      (ok true)
    )
  )
)

;; Toggle flag (right click)
(define-public (toggle-flag (game-id uint) (x uint) (y uint))
  (let
    (
      (game (unwrap! (map-get? games { game-id: game-id }) ERR_GAME_NOT_FOUND))
      (stats (unwrap! (map-get? game-stats { game-id: game-id }) ERR_GAME_NOT_FOUND))
      (cell-index (unwrap! (get-cell-index game-id x y) ERR_OUT_OF_BOUNDS))
      (flag-data (map-get? flagged-cells { game-id: game-id, cell-index: cell-index }))
      (currently-flagged (is-some flag-data))
    )
    ;; Validate
    (asserts! (is-eq (get player game) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status game) STATUS_IN_PROGRESS) ERR_GAME_ALREADY_FINISHED)
    (asserts! (is-none (map-get? revealed-cells { game-id: game-id, cell-index: cell-index })) ERR_CELL_ALREADY_REVEALED)
    
    ;; Toggle flag
    (if currently-flagged
      ;; Remove flag
      (begin
        (map-delete flagged-cells { game-id: game-id, cell-index: cell-index })
        (map-set game-stats
          { game-id: game-id }
          (merge stats { flags-placed: (- (get flags-placed stats) u1) })
        )
      )
      ;; Add flag
      (begin
        (map-set flagged-cells
          { game-id: game-id, cell-index: cell-index }
          { flagged: true }
        )
        (map-set game-stats
          { game-id: game-id }
          (merge stats { flags-placed: (+ (get flags-placed stats) u1) })
        )
      )
    )
    
    (print {event: "toggle-flag", game-id: game-id, x: x, y: y, player: tx-sender})
    (ok (not currently-flagged))
  )
)

;; ============================================================================
;; GAME COMPLETION
;; ============================================================================

;; Mark game as lost (hit a mine)
(define-public (mark-game-lost (game-id uint))
  (let
    (
      (game (unwrap! (map-get? games { game-id: game-id }) ERR_GAME_NOT_FOUND))
      (time-elapsed (- stacks-block-height (default-to stacks-block-height (get started-at game))))
    )
    ;; Validate
    (asserts! (is-eq (get player game) tx-sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq (get status game) STATUS_IN_PROGRESS) ERR_GAME_ALREADY_FINISHED)
    
    ;; Update game status
    (map-set games
      { game-id: game-id }
      (merge game {
        status: STATUS_LOST,
        finished-at: (some stacks-block-height),
        final-time: (some time-elapsed)
      })
    )
    
    (print {event: "mark-game-lost", game-id: game-id, player: tx-sender})
    (ok true)
  )
)

;; Mark game as won (called by win-checker contract)
(define-public (mark-game-won (game-id uint) (final-score uint))
  (let
    (
      (game (unwrap! (map-get? games { game-id: game-id }) ERR_GAME_NOT_FOUND))
      (time-elapsed (- stacks-block-height (default-to stacks-block-height (get started-at game))))
    )
    ;; Validate (only win-checker can call this)
    ;; In production, use contract-caller check
    (asserts! (is-eq (get status game) STATUS_IN_PROGRESS) ERR_GAME_ALREADY_FINISHED)
    
    ;; Update game status
    (map-set games
      { game-id: game-id }
      (merge game {
        status: STATUS_WON,
        finished-at: (some stacks-block-height),
        final-time: (some time-elapsed),
        final-score: (some final-score)
      })
    )
    
    (print {event: "mark-game-won", game-id: game-id, player: tx-sender, final-score: final-score})
    (ok true)
  )
)

;; ============================================================================
;; READ-ONLY FUNCTIONS
;; ============================================================================

;; Get game info
(define-read-only (get-game-info (game-id uint))
  (map-get? games { game-id: game-id })
)

;; Get game stats
(define-read-only (get-game-stats (game-id uint))
  (map-get? game-stats { game-id: game-id })
)

;; Get revealed cell info
(define-read-only (get-revealed-cell (game-id uint) (x uint) (y uint))
  (match (get-cell-index game-id x y)
    ok-val (map-get? revealed-cells { game-id: game-id, cell-index: ok-val })
    err-val none
  )
)

;; Check if cell is flagged
(define-read-only (is-cell-flagged (game-id uint) (x uint) (y uint))
  (match (get-cell-index game-id x y)
    ok-val (is-some (map-get? flagged-cells { game-id: game-id, cell-index: ok-val }))
    err-val false
  )
)

;; Get player's active games
(define-read-only (get-player-active-games (player principal))
  ;; In production, maintain a separate map for this
  ;; For now, return placeholder
  (ok (list))
)

;; ============================================================================
;; ADMIN FUNCTIONS
;; ============================================================================

;; Pause/unpause contract
(define-public (set-contract-paused (paused bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set contract-paused paused)
    (print {event: "set-contract-paused", paused: paused, sender: tx-sender})
    (ok true)
  )
)
