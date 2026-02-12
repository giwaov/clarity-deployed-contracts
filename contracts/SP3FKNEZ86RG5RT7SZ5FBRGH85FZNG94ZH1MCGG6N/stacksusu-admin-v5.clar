;; StackSusu Admin v5
;; Protocol administration, fees, and configuration

(define-constant CONTRACT-OWNER tx-sender)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-PAUSED (err u1021))
(define-constant ERR-ZERO-AMOUNT (err u1023))
(define-constant ERR-TRANSFER-FAILED (err u1017))
(define-constant ERR-INVALID-FEE (err u1025))

;; Protocol state
(define-data-var protocol-paused bool false)

;; Fee configuration (in basis points, 100 = 1%)
(define-data-var admin-fee-bps uint u50)           ;; 0.5% standard fee
(define-data-var emergency-fee-bps uint u200)      ;; 2% emergency withdrawal fee
(define-data-var referral-fee-bps uint u25)        ;; 0.25% referral bonus
(define-data-var late-fee-bps uint u100)           ;; 1% late contribution fee

;; Fee limits
(define-constant MAX-ADMIN-FEE u500)      ;; 5% max
(define-constant MAX-EMERGENCY-FEE u1000) ;; 10% max
(define-constant MAX-REFERRAL-FEE u100)   ;; 1% max
(define-constant MAX-LATE-FEE u500)       ;; 5% max

;; Treasury and stats
(define-data-var treasury-address principal CONTRACT-OWNER)
(define-data-var total-fees-collected uint u0)
(define-data-var total-referral-paid uint u0)
(define-data-var total-circles-created uint u0)
(define-data-var total-payouts-processed uint u0)

;; Authorized contracts
(define-map authorized-contracts principal bool)

;; Protocol settings
(define-data-var min-reputation-score uint u0)           ;; Minimum rep to join circles
(define-data-var reputation-required bool false)         ;; Whether reputation check is enforced
(define-data-var max-circles-per-member uint u20)        ;; Max active circles per member
(define-data-var grace-period-blocks uint u144)          ;; 1 day grace for late deposits


;; ============================================
;; Authorization Functions
;; ============================================

(define-read-only (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-read-only (is-authorized-contract (caller principal))
  (default-to false (map-get? authorized-contracts caller))
)

(define-public (authorize-contract (contract principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-contracts contract true))
  )
)

(define-public (revoke-contract (contract principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-contracts contract))
  )
)


;; ============================================
;; Pause Functions
;; ============================================

(define-public (pause-protocol)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set protocol-paused true))
  )
)

(define-public (unpause-protocol)
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set protocol-paused false))
  )
)

(define-read-only (is-paused)
  (var-get protocol-paused)
)


;; ============================================
;; Fee Management
;; ============================================

(define-public (set-admin-fee (new-fee-bps uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee-bps MAX-ADMIN-FEE) ERR-INVALID-FEE)
    (ok (var-set admin-fee-bps new-fee-bps))
  )
)

(define-public (set-emergency-fee (new-fee-bps uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee-bps MAX-EMERGENCY-FEE) ERR-INVALID-FEE)
    (ok (var-set emergency-fee-bps new-fee-bps))
  )
)

(define-public (set-referral-fee (new-fee-bps uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee-bps MAX-REFERRAL-FEE) ERR-INVALID-FEE)
    (ok (var-set referral-fee-bps new-fee-bps))
  )
)

(define-public (set-late-fee (new-fee-bps uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee-bps MAX-LATE-FEE) ERR-INVALID-FEE)
    (ok (var-set late-fee-bps new-fee-bps))
  )
)

(define-public (set-treasury (new-treasury principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set treasury-address new-treasury))
  )
)

;; Fee getters
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

(define-read-only (get-total-fees)
  (var-get total-fees-collected)
)


;; ============================================
;; Protocol Settings
;; ============================================

(define-public (set-min-reputation (min-score uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set min-reputation-score min-score))
  )
)

(define-public (set-reputation-required (required bool))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set reputation-required required))
  )
)

(define-public (set-max-circles-per-member (max-circles uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set max-circles-per-member max-circles))
  )
)

(define-public (set-grace-period (blocks uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (ok (var-set grace-period-blocks blocks))
  )
)

;; Settings getters
(define-read-only (get-min-reputation)
  (var-get min-reputation-score)
)

(define-read-only (is-reputation-required)
  (var-get reputation-required)
)

(define-read-only (get-max-circles-per-member)
  (var-get max-circles-per-member)
)

(define-read-only (get-grace-period)
  (var-get grace-period-blocks)
)


;; ============================================
;; Statistics Recording
;; ============================================

(define-public (record-fee (amount uint))
  (begin
    (asserts! (or (is-authorized-contract contract-caller) (is-contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set total-fees-collected (+ (var-get total-fees-collected) amount)))
  )
)

(define-public (record-referral-payment (amount uint))
  (begin
    (asserts! (or (is-authorized-contract contract-caller) (is-contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set total-referral-paid (+ (var-get total-referral-paid) amount)))
  )
)

(define-public (increment-circles-created)
  (begin
    (asserts! (or (is-authorized-contract contract-caller) (is-contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set total-circles-created (+ (var-get total-circles-created) u1)))
  )
)

(define-public (increment-payouts-processed)
  (begin
    (asserts! (or (is-authorized-contract contract-caller) (is-contract-owner)) ERR-NOT-AUTHORIZED)
    (ok (var-set total-payouts-processed (+ (var-get total-payouts-processed) u1)))
  )
)


;; ============================================
;; Protocol Statistics (Read-only)
;; ============================================

(define-read-only (get-protocol-stats)
  {
    total-fees: (var-get total-fees-collected),
    total-referrals-paid: (var-get total-referral-paid),
    total-circles: (var-get total-circles-created),
    total-payouts: (var-get total-payouts-processed),
    is-paused: (var-get protocol-paused)
  }
)

(define-read-only (get-fee-config)
  {
    admin-fee-bps: (var-get admin-fee-bps),
    emergency-fee-bps: (var-get emergency-fee-bps),
    referral-fee-bps: (var-get referral-fee-bps),
    late-fee-bps: (var-get late-fee-bps),
    treasury: (var-get treasury-address)
  }
)

(define-read-only (get-protocol-config)
  {
    min-reputation: (var-get min-reputation-score),
    reputation-required: (var-get reputation-required),
    max-circles-per-member: (var-get max-circles-per-member),
    grace-period-blocks: (var-get grace-period-blocks)
  }
)


;; ============================================
;; Fee Calculation Helpers
;; ============================================

(define-read-only (calculate-admin-fee (amount uint))
  (/ (* amount (var-get admin-fee-bps)) u10000)
)

(define-read-only (calculate-emergency-fee (amount uint))
  (/ (* amount (var-get emergency-fee-bps)) u10000)
)

(define-read-only (calculate-referral-fee (amount uint))
  (/ (* amount (var-get referral-fee-bps)) u10000)
)

(define-read-only (calculate-late-fee (amount uint))
  (/ (* amount (var-get late-fee-bps)) u10000)
)
