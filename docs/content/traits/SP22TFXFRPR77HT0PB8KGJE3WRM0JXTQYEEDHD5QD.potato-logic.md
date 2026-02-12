---
title: "Trait potato-logic"
draft: true
---
```
;; potato-logic.clar
;; "The Hot Potato Cousin" - History Edition

;; 1. CONSTANTS
(define-constant CONTRACT-OWNER tx-sender)
(define-constant INCREMENT u5000000) ;; +5 STX

;; 2. DATA VARIABLES
(define-data-var holder principal tx-sender)
(define-data-var price-tag uint u0)
(define-data-var last-survivor principal tx-sender) ;; New: Tracks the previous winner

;; 3. READ-ONLY FUNCTIONS
(define-read-only (get-state)
    (ok { 
        holder: (var-get holder),
        current_price: (var-get price-tag),
        next_price: (+ (var-get price-tag) INCREMENT),
        last_survivor: (var-get last-survivor) ;; Send this to frontend
    })
)

;; 4. PUBLIC FUNCTIONS
(define-public (buy-potato)
    (let 
        (
            (previous-owner (var-get holder))
            (buyer tx-sender)
            (current-cost (var-get price-tag))
            (cost-to-steal (+ current-cost INCREMENT))
        )
        (asserts! (not (is-eq previous-owner buyer)) (err u100))

        ;; 1. Pay the previous owner
        (try! (stx-transfer? cost-to-steal buyer previous-owner))
        
        ;; 2. Update History (Save previous owner as the Survivor)
        (var-set last-survivor previous-owner)

        ;; 3. Update New State
        (var-set holder buyer)
        (var-set price-tag cost-to-steal)
        
        (ok cost-to-steal)
    )
)
```
