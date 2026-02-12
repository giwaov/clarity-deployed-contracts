;; StackSusu Admin v7
;; Auto-authorized protocol administration - no post-deployment setup required

(define-constant CONTRACT-OWNER tx-sender)
(define-constant DEPLOYER 'SP3FKNEZ86RG5RT7SZ5FBRGH85FZNG94ZH1MCGG6N)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-PAUSED (err u1021))
(define-constant ERR-ZERO-AMOUNT (err u1023))
(define-constant ERR-INVALID-FEE (err u1025))
(define-constant ERR-INTERNAL (err u1099))

;; Protocol state
(define-data-var protocol-paused bool false)
(define-data-var maintenance-mode bool false)

;; Fee configuration (in basis points, 100 = 1%)
(define-data-var admin-fee-bps uint u50)           ;; 0.5% standard fee
(define-data-var emergency-fee-bps uint u200)      ;; 2% emergency withdrawal fee
(define-data-var referral-fee-bps uint u25)        ;; 0.25% referral bonus
(define-data-var late-fee-bps uint u100)           ;; 1% late contribution fee

;; Fee limits
(define-constant MAX-ADMIN-FEE u500)      ;; 5% max
(define-constant MAX-EMERGENCY-FEE u1000) ;; 10% max

;; Treasury and stats
(define-data-var treasury-address principal CONTRACT-OWNER)
(define-data-var total-fees-collected uint u0)
(define-data-var total-circles-created uint u0)
(define-data-var total-payouts-processed uint u0)

;; Authorized contracts - ANYONE can call increment functions
;; This removes the authorization barrier while keeping tracking
(define-data-var open-access bool true)


;; ============================================
;; Authorization Functions (simplified)
;; ============================================

(define-read-only (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-read-only (is-paused)
  (var-get protocol-paused)
)

(define-read-only (is-maintenance)
  (var-get maintenance-mode)
)


;; ============================================
;; Pause Functions
;; ============================================

(define-public (pause-protocol)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set protocol-paused true)
    (ok true)
  )
)

(define-public (resume-protocol)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set protocol-paused false)
    (ok true)
  )
)

(define-public (set-maintenance-mode (enabled bool))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set maintenance-mode enabled)
    (ok true)
  )
)


;; ============================================
;; Fee Management
;; ============================================

(define-public (set-admin-fee (new-fee uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee MAX-ADMIN-FEE) ERR-INVALID-FEE)
    (var-set admin-fee-bps new-fee)
    (ok true)
  )
)

(define-public (set-emergency-fee (new-fee uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee MAX-EMERGENCY-FEE) ERR-INVALID-FEE)
    (var-set emergency-fee-bps new-fee)
    (ok true)
  )
)

(define-public (set-treasury (new-treasury principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set treasury-address new-treasury)
    (ok true)
  )
)


;; ============================================
;; Read-only Fee Getters
;; ============================================

(define-read-only (get-admin-fee-bps)
  (var-get admin-fee-bps)
)

(define-read-only (get-emergency-fee-bps)
  (var-get emergency-fee-bps)
)

(define-read-only (get-referral-fee-bps)
  (var-get referral-fee-bps)
)

(define-read-only (get-late-fee-bps)
  (var-get late-fee-bps)
)

(define-read-only (get-treasury)
  (var-get treasury-address)
)


;; ============================================
;; Stats Functions (Open Access - no auth needed)
;; ============================================

(define-public (increment-circles)
  (begin
    (asserts! true ERR-INTERNAL)
    (var-set total-circles-created (+ (var-get total-circles-created) u1))
    (ok true)
  )
)

(define-public (increment-payouts)
  (begin
    (asserts! true ERR-INTERNAL)
    (var-set total-payouts-processed (+ (var-get total-payouts-processed) u1))
    (ok true)
  )
)

(define-public (record-fee (amount uint))
  (begin
    (asserts! true ERR-INTERNAL)
    (var-set total-fees-collected (+ (var-get total-fees-collected) amount))
    (ok true)
  )
)


;; ============================================
;; Stats Read Functions
;; ============================================

(define-read-only (get-protocol-stats)
  {
    total-circles: (var-get total-circles-created),
    total-payouts: (var-get total-payouts-processed),
    total-fees: (var-get total-fees-collected),
    is-paused: (var-get protocol-paused),
    is-maintenance: (var-get maintenance-mode)
  }
)

(define-read-only (get-total-circles)
  (var-get total-circles-created)
)

(define-read-only (get-total-fees)
  (var-get total-fees-collected)
)
