---
title: "Trait smart-ledger"
draft: true
---
```
;; Community Ledger Contract - Final Version
;; This contract allows users to do math and stores their personal "Accumulator"

;; --- 1. DATA STORAGE ---
(define-data-var global-stats-count uint u0)
(define-map user-accumulators principal uint)

;; --- 2. READ-ONLY FUNCTIONS ---
(define-read-only (get-my-value (user principal))
    (default-to u0 (map-get? user-accumulators user))
)

(define-read-only (get-global-count)
    (ok (var-get global-stats-count))
)

;; --- 3. PUBLIC FUNCTIONS ---

;; Add a number to your personal ledger
(define-public (add-to-ledger (to-add uint))
    (begin
        ;; Validation: Check that input is greater than 0
        (asserts! (> to-add u0) (err u100)) 
        
        (let (
            (current-val (default-to u0 (map-get? user-accumulators tx-sender)))
            (new-val (+ current-val to-add))
        )
            (map-set user-accumulators tx-sender new-val)
            (var-set global-stats-count (+ (var-get global-stats-count) u1))
            (ok new-val)
        )
    )
)

;; Simple Calculator (Multiply & Divide)
(define-public (calculate-and-save (num1 uint) (num2 uint))
    (begin
        ;; Validation: Ensure inputs are not 0
        (asserts! (and (> num1 u0) (> num2 u0)) (err u101))

        (let (
            (multiplied (* num1 num2))
            (final-result (/ multiplied u2))
        )
            (map-set user-accumulators tx-sender final-result)
            (var-set global-stats-count (+ (var-get global-stats-count) u1))
            (ok final-result)
        )
    )
)

;; Reset your personal ledger
(define-public (reset-ledger)
    (begin
        (map-set user-accumulators tx-sender u0)
        (ok true)
    )
)
```
