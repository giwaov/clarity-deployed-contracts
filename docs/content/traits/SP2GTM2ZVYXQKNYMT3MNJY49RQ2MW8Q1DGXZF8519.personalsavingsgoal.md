---
title: "Trait personalsavingsgoal"
draft: true
---
```
;; title: savings-goal-jar
;; summary: Lock STX until a specific total savings goal is reached.

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant SAVINGS-GOAL u1000000000) ;; Goal: 1,000 STX (1,000 * 1,000,000 micro-STX)

;; Error codes
(define-constant ERR-NOT-OWNER (err u401))
(define-constant ERR-GOAL-NOT-MET (err u402))
(define-constant ERR-ZERO-DEPOSIT (err u403))

;; Public Functions

;; Deposit STX into the jar
;; @param amount: uint - amount to add to your savings
(define-public (deposit (amount uint))
  (begin
    (asserts! (> amount u0) ERR-ZERO-DEPOSIT)
    ;; Transfer from caller to the contract's own account
    (stx-transfer? amount tx-sender (as-contract tx-sender))
  )
)

;; Withdraw EVERYTHING - only works if goal is reached
(define-public (withdraw-all)
  (let
    (
      (current-balance (stx-get-balance (as-contract tx-sender)))
    )
    (begin
      ;; 1. Security: Only you can trigger the withdrawal
      (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-OWNER)
      
      ;; 2. Logic: Only allow withdrawal if the goal is met
      (asserts! (>= current-balance SAVINGS-GOAL) ERR-GOAL-NOT-MET)
      
      ;; 3. Action: Send the entire balance back to you
      (as-contract (stx-transfer? current-balance (as-contract tx-sender) CONTRACT-OWNER))
    )
  )
)

;; Read-Only Functions

;; Check how much more you need to save
(define-read-only (get-remaining-to-goal)
  (let
    ((current-balance (stx-get-balance (as-contract tx-sender))))
    (if (>= current-balance SAVINGS-GOAL)
      u0
      (- SAVINGS-GOAL current-balance)
    )
  )
)

;; Check current balance of the jar
(define-read-only (get-jar-balance)
  (stx-get-balance (as-contract tx-sender))
)

```
