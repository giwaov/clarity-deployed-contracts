---
title: "Trait blockpay"
draft: true
---
```
;; Title: BlockPay - Decentralized Payroll Streaming
;; Version: 2.0.0
;; Summary: Main payroll contract for real-time salary streaming
;; Description: Enables employers to create salary streams with vesting, employees to withdraw earned wages

;; ============================================
;; Traits
;; ============================================
(use-trait sip-010-trait .sip-010-trait.sip-010-trait)

;; ============================================
;; Constants - Error Codes
;; ============================================
(define-constant ERR_UNAUTHORIZED (err u5000))
(define-constant ERR_STREAM_NOT_FOUND (err u5001))
(define-constant ERR_STREAM_INACTIVE (err u5002))
(define-constant ERR_INSUFFICIENT_FUNDS (err u5003))
(define-constant ERR_INVALID_AMOUNT (err u5004))
(define-constant ERR_INVALID_DURATION (err u5005))
(define-constant ERR_INVALID_EMPLOYEE (err u5006))
(define-constant ERR_STREAM_PAUSED (err u5007))
(define-constant ERR_STREAM_COMPLETED (err u5008))
(define-constant ERR_STREAM_CANCELLED (err u5009))
(define-constant ERR_NOTHING_TO_WITHDRAW (err u5010))
(define-constant ERR_MODIFICATION_NOT_ALLOWED (err u5011))
(define-constant ERR_SYSTEM_PAUSED (err u5012))
(define-constant ERR_CLIFF_NOT_REACHED (err u5013))
(define-constant ERR_INVALID_VESTING_TYPE (err u5014))
(define-constant ERR_TOO_MANY_STREAMS (err u5015))

;; ============================================
;; Constants - Configuration
;; ============================================
(define-constant MAX_STREAMS_PER_EMPLOYER u200)
(define-constant MAX_STREAMS_PER_EMPLOYEE u200)
(define-constant STATUS_ACTIVE "active")
(define-constant STATUS_PAUSED "paused")
(define-constant STATUS_CANCELLED "cancelled")
(define-constant STATUS_COMPLETED "completed")
(define-constant VESTING_LINEAR "linear")
(define-constant VESTING_CLIFF_LINEAR "cliff-linear")

;; ============================================
;; Data Variables
;; ============================================
(define-data-var next-stream-id uint u1)
(define-data-var total-streams-created uint u0)
(define-data-var total-amount-streamed uint u0)

;; ============================================
;; Data Maps - Stream Data
;; ============================================
(define-map streams
    { stream-id: uint }
    {
        employer: principal,
        employee: principal,
        token-contract: (optional principal),
        total-amount: uint,
        rate-per-block: uint,
        start-block: uint,
        end-block: uint,
        cliff-block: (optional uint),
        last-withdrawal-block: uint,
        total-withdrawn: uint,
        status: (string-ascii 20),
        vesting-type: (string-ascii 20),
        can-modify: bool,
        metadata: (string-utf8 256),
        created-at: uint
    }
)

;; ============================================
;; Data Maps - Stream Indexes
;; ============================================
(define-map employer-streams principal (list 200 uint))
(define-map employee-streams principal (list 200 uint))

;; ============================================
;; Data Maps - Stream Modifications History
;; ============================================
(define-map stream-modifications
    { stream-id: uint }
    (list 10 { 
        block: uint, 
        field: (string-ascii 20), 
        old-value: uint, 
        new-value: uint,
        by: principal
    })
)

;; ============================================
;; Data Maps - Pause Tracking
;; ============================================
(define-map stream-pause-data
    { stream-id: uint }
    {
        total-paused-blocks: uint,
        last-pause-block: (optional uint)
    }
)

;; ============================================
;; Read-Only Functions - Stream Queries
;; ============================================

(define-read-only (get-stream (stream-id uint))
    (map-get? streams { stream-id: stream-id })
)

(define-read-only (get-employer-streams (employer principal))
    (default-to (list) (map-get? employer-streams employer))
)

(define-read-only (get-employee-streams (employee principal))
    (default-to (list) (map-get? employee-streams employee))
)

(define-read-only (get-stream-modifications (stream-id uint))
    (default-to (list) (map-get? stream-modifications { stream-id: stream-id }))
)

(define-read-only (get-next-stream-id)
    (var-get next-stream-id)
)

(define-read-only (get-total-streams-created)
    (var-get total-streams-created)
)

;; ============================================
;; Read-Only Functions - Calculations
;; ============================================

(define-read-only (get-earned-amount (stream-id uint))
    (let
        (
            (stream (unwrap! (get-stream stream-id) ERR_STREAM_NOT_FOUND))
            (current-block block-height)
            (rate (get rate-per-block stream))
            (last-block (get last-withdrawal-block stream))
            (total-amount (get total-amount stream))
            (total-withdrawn (get total-withdrawn stream))
            (vesting-type (get vesting-type stream))
            (start-block (get start-block stream))
            (end-block (get end-block stream))
            (cliff-block (get cliff-block stream))
        )
        ;; Calculate time-based earned
        (let
            (
                (blocks-elapsed (if (> current-block last-block) (- current-block last-block) u0))
                (time-earned (* blocks-elapsed rate))
                (total-time-earned (+ total-withdrawn time-earned))
            )
            ;; Apply vesting limits
            (if (is-eq vesting-type VESTING_LINEAR)
                (let
                    (
                        (vested (unwrap-panic (contract-call? .stream-math calculate-linear-vested 
                            total-amount start-block end-block current-block)))
                    )
                    (ok (if (< total-time-earned vested) time-earned (- vested total-withdrawn)))
                )
                (if (is-eq vesting-type VESTING_CLIFF_LINEAR)
                    (let
                        (
                            (cliff (unwrap! cliff-block ERR_INVALID_VESTING_TYPE))
                            (vested (unwrap-panic (contract-call? .stream-math calculate-cliff-vested 
                                total-amount start-block cliff end-block current-block)))
                        )
                        (ok (if (< total-time-earned vested) time-earned (- vested total-withdrawn)))
                    )
                    ;; No vesting, just time-based
                    (ok time-earned)
                )
            )
        )
    )
)

(define-read-only (get-withdrawable-amount (stream-id uint))
    (let
        (
            (stream (unwrap! (get-stream stream-id) ERR_STREAM_NOT_FOUND))
            (earned (unwrap-panic (get-earned-amount stream-id)))
        )
        (ok earned)
    )
)

(define-read-only (get-remaining-amount (stream-id uint))
    (let
        (
            (stream (unwrap! (get-stream stream-id) ERR_STREAM_NOT_FOUND))
        )
        (ok (- (get total-amount stream) (get total-withdrawn stream)))
    )
)

(define-read-only (get-stream-status (stream-id uint))
    (let
        (
            (stream (unwrap! (get-stream stream-id) ERR_STREAM_NOT_FOUND))
        )
        (ok (get status stream))
    )
)

;; ============================================
;; Private Functions - Helpers
;; ============================================

(define-private (add-stream-to-employer (employer principal) (stream-id uint))
    (let
        (
            (current-streams (default-to (list) (map-get? employer-streams employer)))
        )
        (map-set employer-streams employer 
            (unwrap-panic (as-max-len? (append current-streams stream-id) u200)))
    )
)

(define-private (add-stream-to-employee (employee principal) (stream-id uint))
    (let
        (
            (current-streams (default-to (list) (map-get? employee-streams employee)))
        )
        (map-set employee-streams employee 
            (unwrap-panic (as-max-len? (append current-streams stream-id) u200)))
    )
)

(define-private (add-modification-record 
    (stream-id uint) 
    (field (string-ascii 20)) 
    (old-value uint) 
    (new-value uint))
    (let
        (
            (current-mods (default-to (list) (map-get? stream-modifications { stream-id: stream-id })))
            (new-mod { 
                block: block-height, 
                field: field, 
                old-value: old-value, 
                new-value: new-value,
                by: tx-sender
            })
        )
        (map-set stream-modifications { stream-id: stream-id }
            (unwrap-panic (as-max-len? (append current-mods new-mod) u10)))
    )
)

;; ============================================
;; Public Functions - Stream Creation
;; ============================================

(define-public (create-stream
    (employee principal)
    (total-amount uint)
    (duration-blocks uint)
    (vesting-type (string-ascii 20))
    (cliff-blocks (optional uint))
    (can-modify bool)
    (metadata (string-utf8 256)))
    (let
        (
            (employer tx-sender)
            (stream-id (var-get next-stream-id))
            (start-block block-height)
            (end-block (+ start-block duration-blocks))
            (cliff-block (match cliff-blocks
                blocks (some (+ start-block blocks))
                none))
            (rate-per-block (unwrap-panic (contract-call? .stream-math calculate-rate-per-block 
                total-amount duration-blocks)))
        )
        ;; Validations
        (asserts! (contract-call? .access-control is-employer employer) ERR_UNAUTHORIZED)
        (asserts! (> total-amount u0) ERR_INVALID_AMOUNT)
        (asserts! (> duration-blocks u0) ERR_INVALID_DURATION)
        (asserts! (not (is-eq employee employer)) ERR_INVALID_EMPLOYEE)
        
        ;; Check employer has sufficient balance in treasury
        (asserts! (>= (contract-call? .treasury get-employer-stx-balance employer) 
            total-amount) ERR_INSUFFICIENT_FUNDS)
        
        ;; Create stream
        (map-set streams { stream-id: stream-id }
            {
                employer: employer,
                employee: employee,
                token-contract: none,
                total-amount: total-amount,
                rate-per-block: rate-per-block,
                start-block: start-block,
                end-block: end-block,
                cliff-block: cliff-block,
                last-withdrawal-block: start-block,
                total-withdrawn: u0,
                status: STATUS_ACTIVE,
                vesting-type: vesting-type,
                can-modify: can-modify,
                metadata: metadata,
                created-at: block-height
            }
        )
        
        ;; Update indexes
        (add-stream-to-employer employer stream-id)
        (add-stream-to-employee employee stream-id)
        
        ;; Update counters
        (var-set next-stream-id (+ stream-id u1))
        (var-set total-streams-created (+ (var-get total-streams-created) u1))
        
        ;; Emit event
        (print {
            event: "stream-created",
            stream-id: stream-id,
            employer: employer,
            employee: employee,
            total-amount: total-amount,
            duration-blocks: duration-blocks,
            rate-per-block: rate-per-block,
            vesting-type: vesting-type,
            block: block-height
        })
        
        (ok stream-id)
    )
)

;; ============================================
;; Public Functions - Withdrawals
;; ============================================

(define-public (withdraw (stream-id uint))
    (let
        (
            (stream (unwrap! (get-stream stream-id) ERR_STREAM_NOT_FOUND))
            (employee tx-sender)
            (employer (get employer stream))
            (earned (unwrap-panic (get-earned-amount stream-id)))
        )
        ;; Validations
        (asserts! (is-eq employee (get employee stream)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status stream) STATUS_ACTIVE) ERR_STREAM_INACTIVE)
        (asserts! (> earned u0) ERR_NOTHING_TO_WITHDRAW)
        
        ;; Check if stream is paused
        (asserts! (not (contract-call? .emergency-controls is-stream-paused stream-id)) 
            ERR_STREAM_PAUSED)
        (asserts! (contract-call? .emergency-controls is-operational) 
            ERR_SYSTEM_PAUSED)
        
        ;; Withdraw from treasury
        (try! (contract-call? .treasury withdraw-stx employer earned employee))
        
        ;; Update stream
        (let
            (
                (new-total-withdrawn (+ (get total-withdrawn stream) earned))
                (new-status (if (is-eq new-total-withdrawn (get total-amount stream))
                    STATUS_COMPLETED
                    STATUS_ACTIVE))
            )
            (map-set streams { stream-id: stream-id }
                (merge stream {
                    last-withdrawal-block: block-height,
                    total-withdrawn: new-total-withdrawn,
                    status: new-status
                })
            )
            
            ;; Update global counter
            (var-set total-amount-streamed (+ (var-get total-amount-streamed) earned))
            
            ;; Emit event
            (print {
                event: "withdrawal",
                stream-id: stream-id,
                employee: employee,
                amount: earned,
                total-withdrawn: new-total-withdrawn,
                status: new-status,
                block: block-height
            })
            
            (ok earned)
        )
    )
)

;; ============================================
;; Public Functions - Stream Modification
;; ============================================

(define-public (extend-stream (stream-id uint) (additional-blocks uint))
    (let
        (
            (stream (unwrap! (get-stream stream-id) ERR_STREAM_NOT_FOUND))
            (employer tx-sender)
        )
        ;; Validations
        (asserts! (is-eq employer (get employer stream)) ERR_UNAUTHORIZED)
        (asserts! (get can-modify stream) ERR_MODIFICATION_NOT_ALLOWED)
        (asserts! (is-eq (get status stream) STATUS_ACTIVE) ERR_STREAM_INACTIVE)
        (asserts! (> additional-blocks u0) ERR_INVALID_DURATION)
        
        ;; Update stream
        (let
            (
                (old-end (get end-block stream))
                (new-end (+ old-end additional-blocks))
                (new-rate (unwrap-panic (contract-call? .stream-math calculate-rate-per-block
                    (- (get total-amount stream) (get total-withdrawn stream))
                    (- new-end block-height))))
            )
            (map-set streams { stream-id: stream-id }
                (merge stream {
                    end-block: new-end,
                    rate-per-block: new-rate
                })
            )
            
            ;; Record modification
            (add-modification-record stream-id "end-block" old-end new-end)
            
            ;; Emit event
            (print {
                event: "stream-extended",
                stream-id: stream-id,
                old-end-block: old-end,
                new-end-block: new-end,
                additional-blocks: additional-blocks,
                block: block-height
            })
            
            (ok true)
        )
    )
)

(define-public (increase-stream-amount (stream-id uint) (additional-amount uint))
    (let
        (
            (stream (unwrap! (get-stream stream-id) ERR_STREAM_NOT_FOUND))
            (employer tx-sender)
        )
        ;; Validations
        (asserts! (is-eq employer (get employer stream)) ERR_UNAUTHORIZED)
        (asserts! (get can-modify stream) ERR_MODIFICATION_NOT_ALLOWED)
        (asserts! (is-eq (get status stream) STATUS_ACTIVE) ERR_STREAM_INACTIVE)
        (asserts! (> additional-amount u0) ERR_INVALID_AMOUNT)
        
        ;; Check employer has sufficient balance
        (asserts! (>= (contract-call? .treasury get-employer-stx-balance employer) 
            additional-amount) ERR_INSUFFICIENT_FUNDS)
        
        ;; Update stream
        (let
            (
                (old-amount (get total-amount stream))
                (new-amount (+ old-amount additional-amount))
                (remaining-blocks (- (get end-block stream) block-height))
                (new-rate (unwrap-panic (contract-call? .stream-math calculate-rate-per-block
                    (- new-amount (get total-withdrawn stream))
                    remaining-blocks)))
            )
            (map-set streams { stream-id: stream-id }
                (merge stream {
                    total-amount: new-amount,
                    rate-per-block: new-rate
                })
            )
            
            ;; Record modification
            (add-modification-record stream-id "total-amount" old-amount new-amount)
            
            ;; Emit event
            (print {
                event: "stream-amount-increased",
                stream-id: stream-id,
                old-amount: old-amount,
                new-amount: new-amount,
                additional-amount: additional-amount,
                block: block-height
            })
            
            (ok true)
        )
    )
)

;; ============================================
;; Public Functions - Stream Control
;; ============================================

(define-public (cancel-stream (stream-id uint))
    (let
        (
            (stream (unwrap! (get-stream stream-id) ERR_STREAM_NOT_FOUND))
            (employer tx-sender)
            (employee (get employee stream))
        )
        ;; Validations
        (asserts! (is-eq employer (get employer stream)) ERR_UNAUTHORIZED)
        (asserts! (is-eq (get status stream) STATUS_ACTIVE) ERR_STREAM_INACTIVE)
        
        ;; Calculate refund (unvested/unearned amount)
        (let
            (
                (total-amount (get total-amount stream))
                (total-withdrawn (get total-withdrawn stream))
                (earned (unwrap-panic (get-earned-amount stream-id)))
                (refund-amount (- total-amount total-withdrawn earned))
            )
            ;; If there's earned but not withdrawn, transfer to employee first
            (if (> earned u0)
                (try! (contract-call? .treasury withdraw-stx employer earned employee))
                true
            )
            
            ;; Update stream status
            (map-set streams { stream-id: stream-id }
                (merge stream {
                    status: STATUS_CANCELLED,
                    total-withdrawn: (+ total-withdrawn earned)
                })
            )
            
            ;; Emit event
            (print {
                event: "stream-cancelled",
                stream-id: stream-id,
                refund-amount: refund-amount,
                final-payment: earned,
                block: block-height
            })
            
            (ok refund-amount)
        )
    )
)

;; ============================================
;; Public Functions - Batch Operations
;; ============================================

(define-public (batch-create-streams
    (employees (list 50 principal))
    (amounts (list 50 uint))
    (durations (list 50 uint))
    (vesting-type (string-ascii 20))
    (can-modify bool))
    (let
        (
            (employer tx-sender)
        )
        (asserts! (contract-call? .access-control is-employer employer) ERR_UNAUTHORIZED)
        
        (ok (map batch-create-stream-internal 
            employees 
            amounts 
            durations))
    )
)

(define-private (batch-create-stream-internal 
    (employee principal) 
    (amount uint) 
    (duration uint))
    (unwrap-panic (create-stream employee amount duration VESTING_LINEAR none true u"Batch created"))
)

;; ============================================
;; Public Functions - Bonus Payments
;; ============================================

(define-public (add-bonus (employee principal) (amount uint) (metadata (string-utf8 256)))
    (let
        (
            (employer tx-sender)
        )
        ;; Validations
        (asserts! (contract-call? .access-control is-employer employer) ERR_UNAUTHORIZED)
        (asserts! (> amount u0) ERR_INVALID_AMOUNT)
        (asserts! (>= (contract-call? .treasury get-employer-stx-balance employer) 
            amount) ERR_INSUFFICIENT_FUNDS)
        
        ;; Transfer bonus immediately
        (try! (contract-call? .treasury withdraw-stx employer amount employee))
        
        ;; Emit event
        (print {
            event: "bonus-paid",
            employer: employer,
            employee: employee,
            amount: amount,
            metadata: metadata,
            block: block-height
        })
        
        (ok true)
    )
)

```
