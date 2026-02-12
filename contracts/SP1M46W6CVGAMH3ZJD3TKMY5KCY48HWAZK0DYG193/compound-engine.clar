;; ========================================
;; VAULTAYIELD - COMPOUND ENGINE
;; ========================================
;; Converts BTC rewards to STX and reinvests into stacking
;; Manages DEX integration and share price updates

;; ========================================
;; CONSTANTS
;; ========================================

(define-constant CONTRACT-OWNER tx-sender)

;; Error codes
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ZERO-AMOUNT (err u101))
(define-constant ERR-SLIPPAGE-TOO-HIGH (err u102))
(define-constant ERR-DEX-NOT-SET (err u103))
(define-constant ERR-SWAP-FAILED (err u104))

;; Default configurations
(define-constant DEFAULT-SLIPPAGE-TOLERANCE u50) ;; 0.5% (in basis points: 50/10000)
(define-constant MAX-SLIPPAGE u500) ;; 5% maximum
(define-constant PERFORMANCE-FEE-BPS u200) ;; 2% performance fee (200/10000)
(define-constant BASIS_POINTS u10000)

;; ========================================
;; DATA VARIABLES
;; ========================================

;; DEX contract for BTC->STX swaps
(define-data-var dex-contract (optional principal) none)

;; Slippage protection
(define-data-var slippage-tolerance uint DEFAULT-SLIPPAGE-TOLERANCE)

;; Performance tracking
(define-data-var total-compounded-stx uint u0)
(define-data-var total-compounds uint u0)
(define-data-var last-compound-height uint u0)

;; Phase 3: Contract references
;; Will add harvest-manager-contract and vault-core-contract references

;; Mock DEX mode (for testing without real DEX)
(define-data-var mock-dex-mode bool true)
(define-data-var mock-exchange-rate uint u50000) ;; 1 BTC = 50,000 STX (in micro units)

;; ========================================
;; DATA MAPS
;; ========================================

;; Track compound history: compound-id => details
(define-map compound-history
  uint
  {
    btc-amount: uint,
    stx-received: uint,
    fee-amount: uint,
    block-height: uint
  }
)

;; ========================================
;; READ-ONLY FUNCTIONS
;; ========================================

(define-read-only (get-total-compounded-stx)
  ;; Return total STX compounded across all operations
  (var-get total-compounded-stx)
)

(define-read-only (get-total-compounds)
  ;; Return number of compound operations executed
  (var-get total-compounds)
)

(define-read-only (get-slippage-tolerance)
  ;; Return current slippage tolerance in basis points
  (var-get slippage-tolerance)
)

(define-read-only (get-dex-contract)
  ;; Return configured DEX contract
  (var-get dex-contract)
)

(define-read-only (get-compound-history (compound-id uint))
  ;; Get details of specific compound operation
  (map-get? compound-history compound-id)
)

(define-read-only (calculate-compound-impact (btc-amount uint))
  ;; Estimate STX received and fees for BTC amount
  ;; Uses mock rate or queries DEX
  (let
    (
      (exchange-rate (var-get mock-exchange-rate))
      (gross-stx (/ (* btc-amount exchange-rate) u100000000)) ;; Convert BTC sats to STX
      (performance-fee (/ (* gross-stx PERFORMANCE-FEE-BPS) BASIS_POINTS))
      (net-stx (- gross-stx performance-fee))
    )
    (ok {
      gross-stx: gross-stx,
      performance-fee: performance-fee,
      net-stx: net-stx
    })
  )
)

;; ========================================
;; PRIVATE HELPER FUNCTIONS
;; ========================================

(define-private (calculate-performance-fee (stx-amount uint))
  ;; Calculate 2% performance fee on STX received
  (/ (* stx-amount PERFORMANCE-FEE-BPS) BASIS_POINTS)
)

;; Phase 3: Will add slippage checking for real DEX integration

;; ========================================
;; PUBLIC FUNCTIONS - Placeholder Stubs
;; ========================================

(define-public (execute-compound (btc-amount uint))
  ;; Execute compound using real DEX integration
  ;; Swaps BTC for STX and re-stakes
  (begin
    ;; Validation
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> btc-amount u0) ERR-ZERO-AMOUNT)
    (asserts! (not (var-get mock-dex-mode)) ERR-DEX-NOT-SET)
    (asserts! (is-some (var-get dex-contract)) ERR-DEX-NOT-SET)
    
    ;; TODO Phase 3: Implement real DEX integration
    ;; For now, return error directing to use mock mode
    ;; In Phase 3:
    ;; 1. Call DEX contract to swap BTC for STX
    ;; 2. Verify slippage tolerance
    ;; 3. Calculate performance fee
    ;; 4. Trigger re-staking
    
    ;; Placeholder for Phase 2
    (let
      (
        (estimated-result (unwrap! (calculate-compound-impact btc-amount) ERR-SWAP-FAILED))
      )
      (print {
        event: "compound-requested",
        btc-amount: btc-amount,
        estimated-stx: (get gross-stx estimated-result),
        note: "Real DEX integration in Phase 3, use execute-compound-mock for testing"
      })
      
      ERR-DEX-NOT-SET
    )
  )
)

(define-public (execute-compound-mock (btc-amount uint))
  ;; Execute compound using mock DEX (for testing)
  ;; Simulates BTC->STX swap without actual DEX integration
  (begin
    ;; Validation
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> btc-amount u0) ERR-ZERO-AMOUNT)
    (asserts! (var-get mock-dex-mode) ERR-DEX-NOT-SET)
    
    ;; Calculate swap outcome using mock rate
    (let
      (
        (exchange-rate (var-get mock-exchange-rate))
        (gross-stx (/ (* btc-amount exchange-rate) u100000000)) ;; BTC sats to STX
        (performance-fee (calculate-performance-fee gross-stx))
        (net-stx (- gross-stx performance-fee))
        (compound-id (+ (var-get total-compounds) u1))
      )
      
      ;; Verify reasonable outcome
      (asserts! (> gross-stx u0) ERR-SWAP-FAILED)
      
      ;; Record compound history
      (map-set compound-history compound-id {
        btc-amount: btc-amount,
        stx-received: gross-stx,
        fee-amount: performance-fee,
        block-height: block-height
      })
      
      ;; Update state
      (var-set total-compounded-stx (+ (var-get total-compounded-stx) net-stx))
      (var-set total-compounds compound-id)
      (var-set last-compound-height block-height)
      
      ;; Emit compound event
      (print {
        event: "compound-executed-mock",
        compound-id: compound-id,
        btc-amount: btc-amount,
        stx-received: gross-stx,
        performance-fee: performance-fee,
        net-stx: net-stx,
        exchange-rate: exchange-rate,
        timestamp: block-height
      })
      
      ;; TODO: Trigger re-staking via stacking-strategy
      ;; (contract-call? .stacking-strategy delegate-vault-stx net-stx cycles)
      
      (ok {
        gross-stx: gross-stx,
        performance-fee: performance-fee,
        net-stx: net-stx
      })
    )
  )
)

;; ========================================
;; ADMIN FUNCTIONS
;; ========================================

(define-public (set-dex-contract (dex principal))
  ;; Set authorized DEX contract for swaps
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set dex-contract (some dex))
    (var-set mock-dex-mode false)
    (ok true)
  )
)

(define-public (set-slippage-tolerance (new-tolerance uint))
  ;; Update slippage tolerance (max 5%)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-tolerance MAX-SLIPPAGE) ERR-SLIPPAGE-TOO-HIGH)
    (var-set slippage-tolerance new-tolerance)
    (ok true)
  )
)

;; Phase 3: Will add set-harvest-manager and set-vault-core admin functions

(define-public (set-mock-exchange-rate (rate uint))
  ;; Update mock exchange rate for testing
  ;; Rate format: 1 BTC (100M sats) = rate STX
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> rate u0) ERR-ZERO-AMOUNT)
    (var-set mock-exchange-rate rate)
    (ok true)
  )
)

(define-public (enable-mock-dex-mode)
  ;; Enable mock DEX for testing (no real DEX required)
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set mock-dex-mode true)
    (ok true)
  )
)
