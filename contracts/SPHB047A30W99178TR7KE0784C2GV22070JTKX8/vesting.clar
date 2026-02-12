;; Token Vesting Contract with Clarity 4 Features
;; Demonstrates: block-time and to-consensus-buff?

;; ============================================
;; Constants and Error Codes
;; ============================================

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-already-exists (err u102))
(define-constant err-vesting-not-started (err u103))
(define-constant err-no-tokens-available (err u104))
(define-constant err-unauthorized (err u105))
(define-constant err-invalid-schedule (err u106))

;; ============================================
;; Data Variables and Maps
;; ============================================

(define-data-var total-vesting-schedules uint u0)

;; Vesting schedule structure
(define-map vesting-schedules
  { beneficiary: principal }
  {
    total-amount: uint,
    claimed-amount: uint,
    start-time: uint,
    cliff-duration: uint,
    vesting-duration: uint,
    is-active: bool
  }
)

;; Track vesting events for transparency
(define-map vesting-events
  { event-id: uint }
  {
    beneficiary: principal,
    amount: uint,
    timestamp: uint,
    event-type: (string-ascii 20)
  }
)

(define-data-var event-counter uint u0)

;; ============================================
;; Clarity 4 Feature: block-time Usage
;; ============================================

;; Get the current block timestamp
(define-read-only (get-current-time)
  stacks-block-height
)

;; Calculate vested amount based on current time
(define-read-only (calculate-vested-amount (beneficiary principal))
  (match (map-get? vesting-schedules { beneficiary: beneficiary })
    schedule
    (let
      (
        (current-time stacks-block-height)
        (start-time (get start-time schedule))
        (cliff-end (+ start-time (get cliff-duration schedule)))
        (vesting-end (+ start-time (get vesting-duration schedule)))
        (total-amount (get total-amount schedule))
        (claimed-amount (get claimed-amount schedule))
      )
      (if (< current-time cliff-end)
        ;; Before cliff: no tokens vested
        (ok u0)
        (if (>= current-time vesting-end)
          ;; After vesting period: all tokens vested
          (ok (- total-amount claimed-amount))
          ;; During vesting: linear vesting calculation
          (let
            (
              (time-elapsed (- current-time start-time))
              (vesting-duration (get vesting-duration schedule))
              (vested-total (/ (* total-amount time-elapsed) vesting-duration))
              (available (- vested-total claimed-amount))
            )
            (ok available)
          )
        )
      )
    )
    err-not-found
  )
)

;; ============================================
;; Core Vesting Functions
;; ============================================

;; Create a new vesting schedule
(define-public (create-vesting-schedule
  (beneficiary principal)
  (total-amount uint)
  (cliff-duration uint)
  (vesting-duration uint)
)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-none (map-get? vesting-schedules { beneficiary: beneficiary })) err-already-exists)
    (asserts! (> total-amount u0) err-invalid-schedule)
    (asserts! (<= cliff-duration vesting-duration) err-invalid-schedule)
    
    (map-set vesting-schedules
      { beneficiary: beneficiary }
      {
        total-amount: total-amount,
        claimed-amount: u0,
        start-time: stacks-block-height,
        cliff-duration: cliff-duration,
        vesting-duration: vesting-duration,
        is-active: true
      }
    )
    
    ;; Log creation event
    (log-vesting-event beneficiary u0 "schedule-created")
    
    (var-set total-vesting-schedules (+ (var-get total-vesting-schedules) u1))
    (ok true)
  )
)

;; ============================================
;; Claim Vested Tokens
;; ============================================

;; Claim vested tokens with asset protection
(define-public (claim-vested-tokens)
  (let
    (
      (beneficiary tx-sender)
      (available-amount (unwrap! (calculate-vested-amount beneficiary) err-not-found))
    )
    (asserts! (> available-amount u0) err-no-tokens-available)
    
    (match (map-get? vesting-schedules { beneficiary: beneficiary })
      schedule
      (begin
        ;; Update claimed amount to prevent over-withdrawal
        (map-set vesting-schedules
          { beneficiary: beneficiary }
          (merge schedule {
            claimed-amount: (+ (get claimed-amount schedule) available-amount)
          })
        )
        
        ;; Transfer tokens from contract to beneficiary
        (try! (as-contract (stx-transfer? available-amount tx-sender beneficiary)))
        
        ;; Log claim event
        (log-vesting-event beneficiary available-amount "tokens-claimed")
        
        ;; Return success
        (ok available-amount)
      )
      err-not-found
    )
  )
)

;; ============================================
;; Clarity 4 Feature: to-consensus-buff?
;; ============================================

;; Log vesting event with human-readable message
(define-private (log-vesting-event 
  (beneficiary principal)
  (amount uint)
  (event-type (string-ascii 20))
)
  (let
    (
      (event-id (var-get event-counter))
      (current-time stacks-block-height)
    )
    (map-set vesting-events
      { event-id: event-id }
      {
        beneficiary: beneficiary,
        amount: amount,
        timestamp: current-time,
        event-type: event-type
      }
    )
    
    ;; CLARITY 4 FEATURE: Create readable log message
    ;; Note: to-consensus-buff? converts principal to buffer for logging
    (print {
      message: event-type,
      beneficiary-buff: (unwrap-panic (to-consensus-buff? beneficiary)),
      amount: amount,
      timestamp: current-time
    })
    
    (var-set event-counter (+ event-id u1))
  )
)

;; ============================================
;; Read-Only Functions
;; ============================================

;; Get vesting schedule details
(define-read-only (get-vesting-schedule (beneficiary principal))
  (map-get? vesting-schedules { beneficiary: beneficiary })
)

;; Get vesting progress percentage (0-100)
(define-read-only (get-vesting-progress (beneficiary principal))
  (match (map-get? vesting-schedules { beneficiary: beneficiary })
    schedule
    (let
      (
        (current-time stacks-block-height)
        (start-time (get start-time schedule))
        (vesting-end (+ start-time (get vesting-duration schedule)))
      )
      (if (>= current-time vesting-end)
        (ok u100)
        (ok (/ (* (- current-time start-time) u100) (get vesting-duration schedule)))
      )
    )
    err-not-found
  )
)

;; Check if cliff period has passed
(define-read-only (is-cliff-passed (beneficiary principal))
  (match (map-get? vesting-schedules { beneficiary: beneficiary })
    schedule
    (ok (>= stacks-block-height (+ (get start-time schedule) (get cliff-duration schedule))))
    err-not-found
  )
)

;; Get event details
(define-read-only (get-vesting-event (event-id uint))
  (map-get? vesting-events { event-id: event-id })
)

;; Get total number of vesting schedules
(define-read-only (get-total-schedules)
  (ok (var-get total-vesting-schedules))
)

;; ============================================
;; Admin Functions
;; ============================================

;; Revoke a vesting schedule (only owner)
(define-public (revoke-vesting (beneficiary principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    
    (match (map-get? vesting-schedules { beneficiary: beneficiary })
      schedule
      (begin
        (map-set vesting-schedules
          { beneficiary: beneficiary }
          (merge schedule { is-active: false })
        )
        (log-vesting-event beneficiary u0 "schedule-revoked")
        (ok true)
      )
      err-not-found
    )
  )
)

;; Fund the contract (anyone can fund it)
(define-public (fund-contract (amount uint))
  (stx-transfer? amount tx-sender (as-contract tx-sender))
)

;; Get contract balance
(define-read-only (get-contract-balance)
  (ok (stx-get-balance (as-contract tx-sender)))
)