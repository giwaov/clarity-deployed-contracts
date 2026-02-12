---
title: "Trait multisender"
draft: true
---
```
;; title: multi-transfer
;; version: 1.0.0
;; summary: Batch STX transfers to multiple recipients in a single transaction
;; description: Enables efficient batch payments by allowing a sender to transfer
;;              STX to up to 200 recipients in one atomic transaction. All transfers
;;              succeed or all revert.

;; traits
;;

;; token definitions
;;

;; constants
;;

;; Error codes
(define-constant ERR-EMPTY-LIST (err u100))
(define-constant ERR-TRANSFER-FAILED (err u101))
(define-constant ERR-ZERO-AMOUNT (err u102))

;; Maximum transfers per call (Clarity computational limit)
(define-constant MAX-TRANSFERS u200)

;; data vars
;;

;; data maps
;;

;; private functions
;;

;; Execute a single transfer within the fold operation
;; Accumulates total transferred amount on success, propagates error on failure
(define-private (execute-single-transfer
    (entry {recipient: principal, amount: uint})
    (state (response uint uint)))
  (match state
    prev-total
      (let
        (
          (recipient (get recipient entry))
          (amount (get amount entry))
        )
        (if (is-eq amount u0)
          ERR-ZERO-AMOUNT
          (match (stx-transfer? amount tx-sender recipient)
            success (ok (+ prev-total amount))
            error ERR-TRANSFER-FAILED)))
    err-val (err err-val)))

;; Validate a single transfer entry (for read-only validation)
(define-private (validate-single-transfer
    (entry {recipient: principal, amount: uint})
    (state (response uint uint)))
  (match state
    prev-total
      (let ((amount (get amount entry)))
        (if (is-eq amount u0)
          ERR-ZERO-AMOUNT
          (ok (+ prev-total amount))))
    err-val (err err-val)))

;; public functions
;;

;; Main entry point for batch transfers
;; @param transfers: List of up to 200 transfer entries, each containing recipient and amount
;; @returns: (response uint uint) - Total amount transferred on success, error code on failure
(define-public (multi-transfer (transfers (list 200 {recipient: principal, amount: uint})))
  (begin
    (asserts! (> (len transfers) u0) ERR-EMPTY-LIST)
    (fold execute-single-transfer transfers (ok u0))))

;; read only functions
;;

;; Validate transfers without executing them
;; Useful for frontends to check if a batch would succeed (except balance checks)
;; @param transfers: List of transfer entries to validate
;; @returns: (response uint uint) - Total amount that would be transferred, or error
(define-read-only (validate-transfers (transfers (list 200 {recipient: principal, amount: uint})))
  (begin
    (asserts! (> (len transfers) u0) ERR-EMPTY-LIST)
    (fold validate-single-transfer transfers (ok u0))))

;; Get the maximum number of transfers allowed per call
(define-read-only (get-max-transfers)
  MAX-TRANSFERS)

```
