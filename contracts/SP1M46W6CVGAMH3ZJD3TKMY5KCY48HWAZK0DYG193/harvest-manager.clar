;; ========================================
;; VAULTAYIELD - HARVEST MANAGER
;; ========================================
;; Detects and claims BTC rewards from completed stacking cycles
;; Tracks reward history and triggers compounding

;; ========================================
;; CONSTANTS
;; ========================================

(define-constant CONTRACT-OWNER tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-CYCLE (err u101))
(define-constant ERR-ALREADY-RECORDED (err u103))
(define-constant ERR-TOO-SOON (err u104))
(define-constant ERR-ZERO-AMOUNT (err u105))

;; Harvest timing
(define-constant DEFAULT-HARVEST-INTERVAL u144) ;; ~1 day in blocks (10 min blocks)
(define-constant MIN-HARVEST-INTERVAL u10) ;; Minimum 10 blocks between harvests

;; ========================================
;; DATA VARIABLES
;; ========================================

;; Total BTC rewards harvested (in satoshis)
(define-data-var total-btc-harvested uint u0)

;; Last harvested cycle
(define-data-var last-harvest-cycle uint u0)

;; Harvest frequency control
(define-data-var harvest-interval uint DEFAULT-HARVEST-INTERVAL)
(define-data-var last-harvest-height uint u0)

;; Phase 3: Contract references
(define-data-var compound-engine-contract (optional principal) none)

;; ========================================
;; DATA MAPS
;; ========================================

;; Track rewards per cycle: cycle-id => btc-amount (sats)
(define-map cycle-rewards uint uint)

;; Track if cycle has been harvested
(define-map cycle-harvested uint bool)

;; ========================================
;; READ-ONLY FUNCTIONS
;; ========================================

(define-read-only (get-cycle-rewards (cycle-id uint))
  ;; Return BTC earned in specific cycle
  ;; Returns u0 if cycle not harvested yet
  (default-to u0 (map-get? cycle-rewards cycle-id))
)

(define-read-only (is-cycle-harvested (cycle-id uint))
  ;; Check if cycle has been harvested
  (default-to false (map-get? cycle-harvested cycle-id))
)

(define-read-only (get-total-btc-harvested)
  ;; Return total BTC harvested across all cycles
  (var-get total-btc-harvested)
)

(define-read-only (get-last-harvest-cycle)
  ;; Return most recently harvested cycle
  (var-get last-harvest-cycle)
)

(define-read-only (get-harvest-interval)
  ;; Return current harvest interval in blocks
  (var-get harvest-interval)
)

(define-read-only (blocks-until-next-harvest)
  ;; Calculate blocks remaining until next harvest allowed
  (let
    (
      (last-harvest (var-get last-harvest-height))
      (interval (var-get harvest-interval))
      (current-height block-height)
      (next-allowed (+ last-harvest interval))
    )
    (if (>= current-height next-allowed)
      u0
      (- next-allowed current-height)
    )
  )
)

;; ========================================
;; PRIVATE FUNCTIONS
;; ========================================

(define-private (can-harvest-now)
  ;; Check if enough time has passed since last harvest
  (let
    (
      (last-harvest (var-get last-harvest-height))
      (interval (var-get harvest-interval))
    )
    (>= (- block-height last-harvest) interval)
  )
)

;; ========================================
;; PUBLIC FUNCTIONS - Placeholder Stubs
;; ========================================

(define-public (harvest-rewards)
  ;; Harvest BTC rewards from completed stacking cycles
  ;; Permissionless function (anyone can trigger)
  ;; Implements cooldown to prevent spam
  (begin
    ;; Check harvest cooldown
    (asserts! (can-harvest-now) ERR-TOO-SOON)
    
    ;; Update last harvest height
    (var-set last-harvest-height block-height)
    
    ;; Emit harvest-attempted event
    ;; In Phase 2: Manual recording via manual-record-reward
    ;; In Phase 3: Will query PoX for actual rewards
    (print {
      event: "harvest-attempted",
      timestamp: block-height,
      last-harvest-cycle: (var-get last-harvest-cycle)
    })
    
    ;; TODO Phase 3: Implement automated reward detection
    ;; 1. Query stacking-strategy for current cycle
    ;; 2. Check if cycles have completed since last harvest
    ;; 3. Query PoX or Bitcoin for BTC received
    ;; 4. Record rewards automatically
    
    ;; For Phase 2: Return success, actual rewards via manual-record-reward
    (ok u0)
  )
)

(define-public (manual-record-reward (cycle-id uint) (btc-amount uint))
  ;; Manually record BTC rewards for a cycle
  ;; Admin-only fallback function
  ;; Cannot overwrite existing records
  (begin
    ;; Validation checks
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> btc-amount u0) ERR-INVALID-CYCLE) ;; Reusing ERR-INVALID-CYCLE for zero amount for now
    (asserts! (not (is-cycle-harvested cycle-id)) ERR-ALREADY-RECORDED)
    
    ;; Record reward amount
    (map-set cycle-rewards cycle-id btc-amount)
    (map-set cycle-harvested cycle-id true)
    
    ;; Update totals
    (var-set total-btc-harvested (+ (var-get total-btc-harvested) btc-amount))
    (var-set last-harvest-cycle cycle-id)
    (var-set last-harvest-height block-height)
    
    ;; Emit harvest event
    (print {
      event: "reward-recorded-manually",
      cycle-id: cycle-id,
      btc-amount: btc-amount,
      total-harvested: (var-get total-btc-harvested),
      timestamp: block-height
    })
    
    (ok btc-amount)
  )
)

(define-public (get-pending-rewards)
  ;; Calculate unharvested BTC rewards
  ;; For Phase 2: Returns u0 (manual reporting only)
  ;; In Phase 3: Will query actual pending rewards
  (ok u0)
  ;; TODO Phase 3: Implement automated reward detection
  ;; Query stacking-strategy for completed cycles
  ;; Calculate rewards not yet harvested
)

;; ========================================
;; CONTRACT REFERENCES (Phase 3)
;; ========================================
;; Phase 3: Will add references to stacking-strategy and compound-engine

;; ========================================
;; ADMIN FUNCTIONS
;; ========================================

(define-public (set-compound-engine (compound-contract principal))
  ;; Set authorized compound-engine contract
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set compound-engine-contract (some compound-contract))
    (ok true)
  )
)

(define-public (set-harvest-interval (new-interval uint))
  ;; Update harvest interval
  ;; Prevent too-frequent harvesting
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (>= new-interval MIN-HARVEST-INTERVAL) ERR-ZERO-AMOUNT)
    (var-set harvest-interval new-interval)
    (ok true)
  )
)
