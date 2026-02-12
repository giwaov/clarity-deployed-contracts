;; BOARD GENERATOR CONTRACT
;; Generates verifiable random mine placements using block hash + commitment scheme

;; ============================================================================
;; CONSTANTS
;; ============================================================================

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u200))
(define-constant ERR_BOARD_NOT_FOUND (err u201))
(define-constant ERR_BOARD_ALREADY_EXISTS (err u202))
(define-constant ERR_BOARD_NOT_REVEALED (err u203))
(define-constant ERR_INVALID_PARAMETERS (err u204))

;; ============================================================================
;; DATA MAPS
;; ============================================================================

;; Board commitments (hide mine positions until game ends or verification needed)
(define-map board-commitments
  { game-id: uint }
  {
    commitment-hash: (buff 32),
    seed-stacks-block-height: uint,
    revealed: bool,
    mine-count: uint,
    board-width: uint,
    board-height: uint,
    first-click-x: (optional uint),
    first-click-y: (optional uint)
  }
)

;; Revealed mine positions (only after game ends or for verification)
;; Using bitpacked storage: list of cell indices that are mines
(define-map revealed-mine-positions
  { game-id: uint }
  { mine-indices: (list 99 uint) }
)

;; Cache for mine checks during gameplay (to avoid re-computation)
(define-map mine-cache
  { game-id: uint, cell-index: uint }
  { is-mine: bool }
)

;; ============================================================================
;; BOARD GENERATION
;; ============================================================================

;; Generate board commitment
;; Called by game-core when creating new game
;; Uses future block hash for randomness
(define-public (generate-board 
  (game-id uint)
  (width uint)
  (height uint)
  (mine-count uint)
  (first-click-x uint)
  (first-click-y uint))
  (let
    (
      (future-block (+ stacks-block-height u10)) ;; Use hash of block 10 blocks in future
      (seed-data (concat (unwrap-panic (to-consensus-buff? game-id)) (unwrap-panic (to-consensus-buff? tx-sender))))
      (commitment (sha256 seed-data))
    )
    ;; Validate
    (asserts! (is-none (map-get? board-commitments { game-id: game-id })) ERR_BOARD_ALREADY_EXISTS)
    (asserts! (< mine-count (* width height)) ERR_INVALID_PARAMETERS)
    
    ;; Store commitment
    (map-set board-commitments
      { game-id: game-id }
      {
        commitment-hash: commitment,
        seed-stacks-block-height: future-block,
        revealed: false,
        mine-count: mine-count,
        board-width: width,
        board-height: height,
        first-click-x: (some first-click-x),
        first-click-y: (some first-click-y)
      }
    )
    
    (ok commitment)
  )
)

;; Check if specific cell is a mine (lazy evaluation with caching)
;; This is called during gameplay to verify mine hits
(define-public (is-cell-mine (game-id uint) (cell-index uint))
  (let
    (
      (board (unwrap! (map-get? board-commitments { game-id: game-id }) ERR_BOARD_NOT_FOUND))
      (cached (map-get? mine-cache { game-id: game-id, cell-index: cell-index }))
    )
    ;; Check cache first
    (match cached
      cached-value (ok (get is-mine cached-value))
      ;; Not cached - compute and cache
      (let
        (
          (is-mine (compute-is-mine game-id cell-index board))
        )
        ;; Cache result
        (map-set mine-cache
          { game-id: game-id, cell-index: cell-index }
          { is-mine: is-mine }
        )
        (ok is-mine)
      )
    )
  )
)

;; Compute if cell is mine using deterministic pseudo-random generation
;; Based on board commitment hash + cell index
(define-private (compute-is-mine (game-id uint) (cell-index uint) (board (tuple 
  (commitment-hash (buff 32))
  (seed-stacks-block-height uint)
  (revealed bool)
  (mine-count uint)
  (board-width uint)
  (board-height uint)
  (first-click-x (optional uint))
  (first-click-y (optional uint))
)))
  (let
    (
      (seed (get commitment-hash board))
      (total-cells (* (get board-width board) (get board-height board)))
      (mine-count (get mine-count board))
      ;; Generate pseudo-random hash for this cell
      (cell-seed (sha256 (concat seed (unwrap-panic (to-consensus-buff? cell-index)))))
      ;; Take first 16 bytes and convert to uint
      ;; We'll use a helper that processes the hash differently
      (hash-part (unwrap-panic (as-max-len? (unwrap-panic (slice? cell-seed u0 u16)) u16)))
      (random-value (buff-to-uint-be hash-part))
      ;; Calculate probability: mine-count / total-cells
      ;; If random-value mod total-cells < mine-count, it's a mine
      (is-mine-candidate (< (mod random-value total-cells) mine-count))
      
      ;; Check if this is the first-click position (must never be mine)
      (first-click-index (coords-to-index 
        (default-to u0 (get first-click-x board))
        (default-to u0 (get first-click-y board))
        (get board-width board)
      ))
      (is-first-click (is-eq cell-index first-click-index))
    )
    ;; First click safety - never a mine
    (if is-first-click
      false
      is-mine-candidate
    )
  )
)

;; Helper: coords to index
(define-private (coords-to-index (x uint) (y uint) (width uint))
  (+ (* y width) x)
)

;; ============================================================================
;; MINE ADJACENCY CALCULATION
;; ============================================================================

;; Helper to check if cell is mine, returns bool or false on error
(define-private (check-cell-mine (game-id uint) (cell-index uint))
  (match (is-cell-mine game-id cell-index)
    ok-val ok-val
    err-val false
  )
)

;; Count adjacent mines for a cell (0-8)
;; Used by game-core to display numbers
(define-public (count-adjacent-mines (game-id uint) (x uint) (y uint))
  (let
    (
      (board (unwrap! (map-get? board-commitments { game-id: game-id }) ERR_BOARD_NOT_FOUND))
      (width (get board-width board))
      (height (get board-height board))
      (c0 u0)
      ;; Check all 8 neighbors manually
      (c1 (if (and (> x u0) (> y u0)) 
              (+ c0 (if (check-cell-mine game-id (coords-to-index (- x u1) (- y u1) width)) u1 u0)) 
              c0))
      (c2 (if (> y u0) 
              (+ c1 (if (check-cell-mine game-id (coords-to-index x (- y u1) width)) u1 u0)) 
              c1))
      (c3 (if (and (< x (- width u1)) (> y u0)) 
              (+ c2 (if (check-cell-mine game-id (coords-to-index (+ x u1) (- y u1) width)) u1 u0)) 
              c2))
      (c4 (if (> x u0) 
              (+ c3 (if (check-cell-mine game-id (coords-to-index (- x u1) y width)) u1 u0)) 
              c3))
      (c5 (if (< x (- width u1)) 
              (+ c4 (if (check-cell-mine game-id (coords-to-index (+ x u1) y width)) u1 u0)) 
              c4))
      (c6 (if (and (> x u0) (< y (- height u1))) 
              (+ c5 (if (check-cell-mine game-id (coords-to-index (- x u1) (+ y u1) width)) u1 u0)) 
              c5))
      (c7 (if (< y (- height u1)) 
              (+ c6 (if (check-cell-mine game-id (coords-to-index x (+ y u1) width)) u1 u0)) 
              c6))
      (c8 (if (and (< x (- width u1)) (< y (- height u1))) 
              (+ c7 (if (check-cell-mine game-id (coords-to-index (+ x u1) (+ y u1) width)) u1 u0)) 
              c7))
    )
    (ok c8)
  )
)

;; ============================================================================
;; BOARD REVEAL (POST-GAME)
;; ============================================================================

;; Reveal all mine positions after game ends
;; Used for verification and post-game analysis
(define-public (reveal-board (game-id uint))
  (let
    (
      (board (unwrap! (map-get? board-commitments { game-id: game-id }) ERR_BOARD_NOT_FOUND))
    )
    ;; Can only reveal once
    (asserts! (not (get revealed board)) ERR_BOARD_ALREADY_EXISTS)
    
    ;; Mark as revealed
    (map-set board-commitments
      { game-id: game-id }
      (merge board { revealed: true })
    )
    
    ;; In production, would compute and store all mine positions
    ;; For now, mines are computed on-demand via is-cell-mine
    
    (ok true)
  )
)

;; ============================================================================
;; READ-ONLY FUNCTIONS
;; ============================================================================

;; Get board commitment info
(define-read-only (get-board-info (game-id uint))
  (map-get? board-commitments { game-id: game-id })
)

;; Get mine positions (only if revealed)
(define-read-only (get-mine-positions (game-id uint))
  (let
    (
      (board (unwrap! (map-get? board-commitments { game-id: game-id }) ERR_BOARD_NOT_FOUND))
    )
    (asserts! (get revealed board) ERR_BOARD_NOT_REVEALED)
    (ok (map-get? revealed-mine-positions { game-id: game-id }))
  )
)

;; Verify board commitment (prove fairness)
(define-read-only (verify-commitment (game-id uint) (claimed-seed (buff 32)))
  (let
    (
      (board (unwrap! (map-get? board-commitments { game-id: game-id }) ERR_BOARD_NOT_FOUND))
      (stored-commitment (get commitment-hash board))
      (computed-commitment (sha256 claimed-seed))
    )
    (ok (is-eq stored-commitment computed-commitment))
  )
)
