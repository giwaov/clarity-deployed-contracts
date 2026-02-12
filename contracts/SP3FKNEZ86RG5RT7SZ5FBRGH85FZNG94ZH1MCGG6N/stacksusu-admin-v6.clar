;; StackSusu Admin v6
;; Enhanced protocol administration with multi-sig and tiered fees

(define-constant CONTRACT-OWNER tx-sender)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u1000))
(define-constant ERR-PAUSED (err u1021))
(define-constant ERR-ZERO-AMOUNT (err u1023))
(define-constant ERR-TRANSFER-FAILED (err u1017))
(define-constant ERR-INVALID-FEE (err u1025))
(define-constant ERR-ALREADY-SIGNER (err u1040))
(define-constant ERR-NOT-SIGNER (err u1041))
(define-constant ERR-THRESHOLD-NOT-MET (err u1042))
(define-constant ERR-ACTION-EXPIRED (err u1043))
(define-constant ERR-ALREADY-SIGNED (err u1044))
(define-constant ERR-INVALID-THRESHOLD (err u1045))

;; Protocol state
(define-data-var protocol-paused bool false)
(define-data-var maintenance-mode bool false)

;; Fee configuration (in basis points, 100 = 1%)
(define-data-var admin-fee-bps uint u50)           ;; 0.5% standard fee
(define-data-var emergency-fee-bps uint u200)      ;; 2% emergency withdrawal fee
(define-data-var referral-fee-bps uint u25)        ;; 0.25% referral bonus
(define-data-var late-fee-bps uint u100)           ;; 1% late contribution fee
(define-data-var insurance-fee-bps uint u10)       ;; 0.1% goes to insurance pool

;; Tiered fee structure (volume-based discounts)
(define-map volume-fee-tiers
  uint  ;; tier level
  { min-volume: uint, fee-discount-bps: uint }
)

;; Fee limits
(define-constant MAX-ADMIN-FEE u500)      ;; 5% max
(define-constant MAX-EMERGENCY-FEE u1000) ;; 10% max
(define-constant MAX-REFERRAL-FEE u100)   ;; 1% max
(define-constant MAX-LATE-FEE u500)       ;; 5% max

;; Multi-sig configuration
(define-data-var multi-sig-threshold uint u2)
(define-data-var multi-sig-action-expiry uint u1008)  ;; ~7 days

;; Multi-sig signers
(define-map multi-sig-signers principal bool)
(define-data-var signer-count uint u1)

;; Pending multi-sig actions
(define-data-var action-nonce uint u0)
(define-map pending-actions
  uint  ;; action-id
  {
    action-type: (string-ascii 30),
    param-uint: uint,
    param-principal: (optional principal),
    created-at: uint,
    signatures: uint,
    executed: bool
  }
)

(define-map action-signatures
  { action-id: uint, signer: principal }
  bool
)

;; Treasury and stats
(define-data-var treasury-address principal CONTRACT-OWNER)
(define-data-var insurance-pool-address principal CONTRACT-OWNER)
(define-data-var total-fees-collected uint u0)
(define-data-var total-referral-paid uint u0)
(define-data-var total-circles-created uint u0)
(define-data-var total-payouts-processed uint u0)
(define-data-var total-insurance-collected uint u0)

;; Analytics tracking
(define-map daily-stats
  uint  ;; day (block-height / BLOCKS-PER-DAY)
  {
    circles-created: uint,
    contributions: uint,
    payouts: uint,
    fees-collected: uint,
    active-members: uint
  }
)

(define-constant BLOCKS-PER-DAY u144)

;; Authorized contracts
(define-map authorized-contracts principal bool)


;; ============================================
;; Multi-Sig Functions
;; ============================================

(define-public (add-signer (new-signer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? multi-sig-signers new-signer)) ERR-ALREADY-SIGNER)
    (map-set multi-sig-signers new-signer true)
    (var-set signer-count (+ (var-get signer-count) u1))
    (ok true)
  )
)

(define-public (remove-signer (signer principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (map-get? multi-sig-signers signer)) ERR-NOT-SIGNER)
    (asserts! (> (var-get signer-count) (var-get multi-sig-threshold)) ERR-INVALID-THRESHOLD)
    (map-delete multi-sig-signers signer)
    (var-set signer-count (- (var-get signer-count) u1))
    (ok true)
  )
)

(define-public (set-threshold (new-threshold uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-threshold u1) (<= new-threshold (var-get signer-count))) ERR-INVALID-THRESHOLD)
    (var-set multi-sig-threshold new-threshold)
    (ok true)
  )
)

(define-public (propose-action (action-type (string-ascii 30)) (param-uint uint) (param-principal (optional principal)))
  (let
    (
      (action-id (+ (var-get action-nonce) u1))
    )
    (asserts! (is-signer tx-sender) ERR-NOT-SIGNER)
    (var-set action-nonce action-id)
    (map-set pending-actions action-id {
      action-type: action-type,
      param-uint: param-uint,
      param-principal: param-principal,
      created-at: block-height,
      signatures: u1,
      executed: false
    })
    (map-set action-signatures { action-id: action-id, signer: tx-sender } true)
    (ok action-id)
  )
)

(define-public (sign-action (action-id uint))
  (let
    (
      (action (unwrap! (map-get? pending-actions action-id) ERR-NOT-AUTHORIZED))
      (already-signed (default-to false (map-get? action-signatures { action-id: action-id, signer: tx-sender })))
    )
    (asserts! (is-signer tx-sender) ERR-NOT-SIGNER)
    (asserts! (not already-signed) ERR-ALREADY-SIGNED)
    (asserts! (not (get executed action)) ERR-NOT-AUTHORIZED)
    (asserts! (< (- block-height (get created-at action)) (var-get multi-sig-action-expiry)) ERR-ACTION-EXPIRED)
    
    (map-set action-signatures { action-id: action-id, signer: tx-sender } true)
    (map-set pending-actions action-id
      (merge action { signatures: (+ (get signatures action) u1) })
    )
    (ok true)
  )
)

(define-read-only (is-signer (caller principal))
  (or (is-eq caller CONTRACT-OWNER) (default-to false (map-get? multi-sig-signers caller)))
)

(define-read-only (get-multi-sig-threshold)
  (ok (var-get multi-sig-threshold))
)


;; ============================================
;; Authorization Functions
;; ============================================

(define-read-only (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-read-only (is-admin (caller principal))
  (or (is-eq caller CONTRACT-OWNER) 
      (default-to false (map-get? multi-sig-signers caller)))
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

(define-read-only (is-paused)
  (var-get protocol-paused)
)

(define-read-only (is-maintenance)
  (var-get maintenance-mode)
)


;; ============================================
;; Fee Configuration
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

(define-public (set-insurance-fee (new-fee uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee u100) ERR-INVALID-FEE)  ;; Max 1%
    (var-set insurance-fee-bps new-fee)
    (ok true)
  )
)

(define-public (setup-volume-tier (tier uint) (min-volume uint) (discount-bps uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= discount-bps u500) ERR-INVALID-FEE)  ;; Max 5% discount
    (map-set volume-fee-tiers tier { min-volume: min-volume, fee-discount-bps: discount-bps })
    (ok true)
  )
)

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

(define-read-only (get-insurance-fee-bps)
  (var-get insurance-fee-bps)
)

(define-read-only (get-effective-fee (base-fee uint) (member-volume uint))
  (let
    (
      (tier-3 (map-get? volume-fee-tiers u3))
      (tier-2 (map-get? volume-fee-tiers u2))
      (tier-1 (map-get? volume-fee-tiers u1))
      (discount (if (and (is-some tier-3) (>= member-volume (get min-volume (unwrap-panic tier-3))))
                  (get fee-discount-bps (unwrap-panic tier-3))
                  (if (and (is-some tier-2) (>= member-volume (get min-volume (unwrap-panic tier-2))))
                    (get fee-discount-bps (unwrap-panic tier-2))
                    (if (and (is-some tier-1) (>= member-volume (get min-volume (unwrap-panic tier-1))))
                      (get fee-discount-bps (unwrap-panic tier-1))
                      u0))))
    )
    (if (> discount base-fee)
      u0
      (- base-fee discount))
  )
)


;; ============================================
;; Treasury Functions
;; ============================================

(define-public (set-treasury (new-treasury principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set treasury-address new-treasury)
    (ok true)
  )
)

(define-public (set-insurance-pool (new-pool principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set insurance-pool-address new-pool)
    (ok true)
  )
)

(define-read-only (get-treasury)
  (ok (var-get treasury-address))
)

(define-read-only (get-insurance-pool)
  (var-get insurance-pool-address)
)

(define-public (record-fee (amount uint))
  (begin
    (asserts! (is-authorized-contract contract-caller) ERR-NOT-AUTHORIZED)
    (var-set total-fees-collected (+ (var-get total-fees-collected) amount))
    (ok true)
  )
)

(define-public (record-insurance-contribution (amount uint))
  (begin
    (asserts! (is-authorized-contract contract-caller) ERR-NOT-AUTHORIZED)
    (var-set total-insurance-collected (+ (var-get total-insurance-collected) amount))
    (ok true)
  )
)


;; ============================================
;; Analytics Functions
;; ============================================

(define-public (record-daily-activity 
    (circles uint) 
    (contributions uint) 
    (payouts uint) 
    (fees uint))
  (let
    (
      (day (/ block-height BLOCKS-PER-DAY))
      (current (default-to {
        circles-created: u0,
        contributions: u0,
        payouts: u0,
        fees-collected: u0,
        active-members: u0
      } (map-get? daily-stats day)))
    )
    (asserts! (is-authorized-contract contract-caller) ERR-NOT-AUTHORIZED)
    (map-set daily-stats day {
      circles-created: (+ (get circles-created current) circles),
      contributions: (+ (get contributions current) contributions),
      payouts: (+ (get payouts current) payouts),
      fees-collected: (+ (get fees-collected current) fees),
      active-members: (get active-members current)
    })
    (ok true)
  )
)

(define-read-only (get-daily-stats (day uint))
  (map-get? daily-stats day)
)

(define-read-only (get-protocol-stats)
  {
    total-fees: (var-get total-fees-collected),
    total-referrals: (var-get total-referral-paid),
    total-circles: (var-get total-circles-created),
    total-payouts: (var-get total-payouts-processed),
    total-insurance: (var-get total-insurance-collected),
    is-paused: (var-get protocol-paused),
    is-maintenance: (var-get maintenance-mode)
  }
)


;; ============================================
;; Increment Functions (for tracking)
;; ============================================

(define-public (increment-circles)
  (begin
    (asserts! (is-authorized-contract contract-caller) ERR-NOT-AUTHORIZED)
    (var-set total-circles-created (+ (var-get total-circles-created) u1))
    (ok true)
  )
)

(define-public (increment-payouts)
  (begin
    (asserts! (is-authorized-contract contract-caller) ERR-NOT-AUTHORIZED)
    (var-set total-payouts-processed (+ (var-get total-payouts-processed) u1))
    (ok true)
  )
)

(define-public (record-referral-payout (amount uint))
  (begin
    (asserts! (is-authorized-contract contract-caller) ERR-NOT-AUTHORIZED)
    (var-set total-referral-paid (+ (var-get total-referral-paid) amount))
    (ok true)
  )
)
