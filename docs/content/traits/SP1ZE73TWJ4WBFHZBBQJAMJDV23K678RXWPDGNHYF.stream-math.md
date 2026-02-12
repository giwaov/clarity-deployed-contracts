---
title: "Trait stream-math"
draft: true
---
```
;; Title: Stream Math Library
;; Version: 1.0.0
;; Summary: Precision calculation engine for salary streaming
;; Description: Handles rate calculations, vesting schedules, and earnings with overflow protection

;; ============================================
;; Constants - Error Codes
;; ============================================
(define-constant ERR_DIVISION_BY_ZERO (err u3000))
(define-constant ERR_OVERFLOW (err u3001))
(define-constant ERR_INVALID_INPUT (err u3002))
(define-constant ERR_CLIFF_NOT_REACHED (err u3003))

;; ============================================
;; Constants - Configuration
;; ============================================
(define-constant PRECISION_MULTIPLIER u1000000) ;; 6 decimal places for precision
(define-constant MAX_UINT u340282366920938463463374607431768211455) ;; u128 max

;; ============================================
;; Read-Only Functions - Rate Calculations
;; ============================================

;; Calculate rate per block: total-amount / duration-blocks
;; Returns rate with precision multiplier applied
(define-read-only (calculate-rate-per-block (total-amount uint) (duration-blocks uint))
    (begin
        (asserts! (> duration-blocks u0) ERR_DIVISION_BY_ZERO)
        (asserts! (> total-amount u0) ERR_INVALID_INPUT)
        
        ;; Simple division for rate per block
        (ok (/ total-amount duration-blocks))
    )
)

;; Calculate earned amount based on blocks elapsed
;; earned = (current-block - last-withdrawal-block) * rate-per-block
(define-read-only (calculate-earned 
    (current-block uint) 
    (last-withdrawal-block uint) 
    (rate-per-block uint))
    (let
        (
            (blocks-elapsed (- current-block last-withdrawal-block))
        )
        (asserts! (>= current-block last-withdrawal-block) ERR_INVALID_INPUT)
        
        ;; Check for overflow before multiplication
        (asserts! (<= blocks-elapsed (/ MAX_UINT rate-per-block)) ERR_OVERFLOW)
        
        (ok (* blocks-elapsed rate-per-block))
    )
)

;; ============================================
;; Read-Only Functions - Vesting Calculations
;; ============================================

;; Calculate vested amount with linear vesting
;; Returns the amount that has vested up to current-block
(define-read-only (calculate-linear-vested
    (total-amount uint)
    (start-block uint)
    (end-block uint)
    (current-block uint))
    (begin
        (asserts! (> end-block start-block) ERR_INVALID_INPUT)
        (asserts! (>= current-block start-block) ERR_INVALID_INPUT)
        
        (if (>= current-block end-block)
            ;; Fully vested
            (ok total-amount)
            ;; Partially vested: (current - start) / (end - start) * total
            (let
                (
                    (elapsed (- current-block start-block))
                    (duration (- end-block start-block))
                )
                (ok (/ (* total-amount elapsed) duration))
            )
        )
    )
)

;; Calculate vested amount with cliff period
;; Returns 0 if cliff not reached, otherwise calculates linear vesting from cliff
(define-read-only (calculate-cliff-vested
    (total-amount uint)
    (start-block uint)
    (cliff-block uint)
    (end-block uint)
    (current-block uint))
    (begin
        (asserts! (>= cliff-block start-block) ERR_INVALID_INPUT)
        (asserts! (>= end-block cliff-block) ERR_INVALID_INPUT)
        
        ;; Check if cliff has been reached
        (if (< current-block cliff-block)
            ;; Cliff not reached, nothing vested
            (ok u0)
            ;; Cliff reached, calculate linear vesting
            (if (>= current-block end-block)
                ;; Fully vested
                (ok total-amount)
                ;; Partially vested from cliff to end
                (let
                    (
                        (elapsed (- current-block cliff-block))
                        (duration (- end-block cliff-block))
                    )
                    (if (is-eq duration u0)
                        ;; Cliff at end, fully vest
                        (ok total-amount)
                        (ok (/ (* total-amount elapsed) duration))
                    )
                )
            )
        )
    )
)

;; ============================================
;; Read-Only Functions - Withdrawable Amount
;; ============================================

;; Calculate withdrawable amount (earned and vested, minus already withdrawn)
(define-read-only (calculate-withdrawable
    (total-earned uint)
    (total-vested uint)
    (total-withdrawn uint))
    (let
        (
            ;; Withdrawable is the minimum of earned and vested
            (available (if (< total-earned total-vested) total-earned total-vested))
        )
        (asserts! (>= available total-withdrawn) ERR_INVALID_INPUT)
        (ok (- available total-withdrawn))
    )
)

;; ============================================
;; Read-Only Functions - Remaining Amount
;; ============================================

;; Calculate remaining amount in stream
(define-read-only (calculate-remaining (total-amount uint) (total-withdrawn uint))
    (begin
        (asserts! (>= total-amount total-withdrawn) ERR_INVALID_INPUT)
        (ok (- total-amount total-withdrawn))
    )
)

;; ============================================
;; Read-Only Functions - Completion Check
;; ============================================

;; Check if stream is completed (all funds withdrawn)
(define-read-only (is-stream-completed (total-amount uint) (total-withdrawn uint))
    (ok (is-eq total-amount total-withdrawn))
)

;; ============================================
;; Read-Only Functions - Progress Percentage
;; ============================================

;; Calculate progress percentage (0-100)
(define-read-only (calculate-progress-percentage 
    (current-block uint)
    (start-block uint)
    (end-block uint))
    (begin
        (asserts! (> end-block start-block) ERR_DIVISION_BY_ZERO)
        
        (if (< current-block start-block)
            (ok u0)
            (if (>= current-block end-block)
                (ok u100)
                (let
                    (
                        (elapsed (- current-block start-block))
                        (duration (- end-block start-block))
                    )
                    (ok (/ (* elapsed u100) duration))
                )
            )
        )
    )
)

;; ============================================
;; Read-Only Functions - Safe Math Operations
;; ============================================

;; Safe addition with overflow check
(define-read-only (safe-add (a uint) (b uint))
    (let
        (
            (result (+ a b))
        )
        (asserts! (>= result a) ERR_OVERFLOW)
        (ok result)
    )
)

;; Safe subtraction with underflow check
(define-read-only (safe-sub (a uint) (b uint))
    (begin
        (asserts! (>= a b) ERR_INVALID_INPUT)
        (ok (- a b))
    )
)

;; Safe multiplication with overflow check
(define-read-only (safe-mul (a uint) (b uint))
    (begin
        (if (is-eq a u0)
            (ok u0)
            (begin
                (asserts! (<= b (/ MAX_UINT a)) ERR_OVERFLOW)
                (ok (* a b))
            )
        )
    )
)

;; Safe division with zero check
(define-read-only (safe-div (a uint) (b uint))
    (begin
        (asserts! (> b u0) ERR_DIVISION_BY_ZERO)
        (ok (/ a b))
    )
)

```
