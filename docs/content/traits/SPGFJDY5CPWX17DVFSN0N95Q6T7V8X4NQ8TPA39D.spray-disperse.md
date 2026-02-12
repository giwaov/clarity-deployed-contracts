---
title: "Trait spray-disperse"
draft: true
---
```
;; SPDX-License-Identifier: MIT
;; Spray Disperse (Stacks / Clarity 3)
;; Disperse STX + SIP-010 fungible tokens to many recipients in a single transaction.
;; Inspired by disperse.app pattern for EVM chains.

;; ============================================
;; Constants
;; ============================================
(define-constant CONTRACT_NAME "spray-disperse")
(define-constant MAX_RECIPIENTS u200)

;; Error codes (keep stable for frontends)
(define-constant ERR_LEN_MISMATCH        (err u100))
(define-constant ERR_EMPTY_RECIPIENTS    (err u101))
(define-constant ERR_NON_POSITIVE_AMOUNT (err u102))
(define-constant ERR_INSUFFICIENT_STX    (err u103))
(define-constant ERR_NOT_OWNER           (err u104))
(define-constant ERR_TRANSFER_FAILED     (err u105))
(define-constant ERR_TOO_MANY_RECIPIENTS (err u106))
(define-constant ERR_ALREADY_FAILED      (err u107))

;; ============================================
;; Imports
;; ============================================
(use-trait sip010-trait .sip010-trait.sip010-trait)

;; ============================================
;; Ownership
;; ============================================
(define-data-var owner principal tx-sender)

(define-read-only (get-owner)
  (var-get owner))

(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get owner)) ERR_NOT_OWNER)
    (var-set owner new-owner)
    (ok true)))

;; Useful for escrow mode - returns address to send tokens to
(define-read-only (get-contract-principal)
  (as-contract tx-sender))

;; ============================================
;; Internal Helpers
;; ============================================

;; Sum all amounts in a list
(define-private (sum-amounts (amounts (list 200 uint)))
  (fold + amounts u0))

;; Validate input lists have same length and are non-empty
(define-private (validate-inputs
    (recipients-len uint)
    (amounts-len uint))
  (begin
    (asserts! (is-eq recipients-len amounts-len) ERR_LEN_MISMATCH)
    (asserts! (> recipients-len u0) ERR_EMPTY_RECIPIENTS)
    (asserts! (<= recipients-len MAX_RECIPIENTS) ERR_TOO_MANY_RECIPIENTS)
    (ok true)))

;; ============================================
;; STX Disperse Implementation
;; ============================================

;; Fold step function for STX transfers
;; Accumulator tracks: index, recipients list, success state, and sender
(define-private (stx-transfer-fold-step
    (amount uint)
    (acc { idx: uint, recipients: (list 200 principal), ok: bool, sender: principal }))
  (let (
    (idx (get idx acc))
    (recipients (get recipients acc))
    (acc-ok (get ok acc))
    (sender (get sender acc))
  )
    ;; If previous transfer failed, propagate failure
    (if (not acc-ok)
        (merge acc { idx: (+ idx u1) })
        ;; Otherwise, attempt transfer
        (match (element-at? recipients idx)
          recipient
            (if (is-eq amount u0)
                ;; Zero amount = failure
                { idx: (+ idx u1), recipients: recipients, ok: false, sender: sender }
                (match (stx-transfer? amount sender recipient)
                  success
                    { idx: (+ idx u1), recipients: recipients, ok: true, sender: sender }
                  error
                    { idx: (+ idx u1), recipients: recipients, ok: false, sender: sender }))
          ;; No recipient at index = failure
          { idx: (+ idx u1), recipients: recipients, ok: false, sender: sender }))))

;; ============================================
;; SIP-010 Token Disperse (Escrow Mode)
;; ============================================

;; Data var to temporarily store token transfers context
;; Used by fold since traits can't be passed to fold callbacks
(define-data-var transfer-context
  { sender: principal, recipient: principal, amount: uint }
  { sender: tx-sender, recipient: tx-sender, amount: u0 })

;; ============================================
;; Public API
;; ============================================

;; Disperse native STX to multiple recipients
;; @param recipients: list of recipient addresses (max 200)
;; @param amounts: list of amounts (must match recipients length)
;; @returns tuple with total dispersed and recipient count
(define-public (disperse-stx
    (recipients (list 200 principal))
    (amounts (list 200 uint)))
  (let (
    (recipients-len (len recipients))
    (amounts-len (len amounts))
    (total (sum-amounts amounts))
    (sender tx-sender)
  )
    ;; Validate inputs
    (try! (validate-inputs recipients-len amounts-len))

    ;; Check sender has sufficient balance
    (asserts! (>= (stx-get-balance sender) total) ERR_INSUFFICIENT_STX)

    ;; Execute transfers using fold
    (let (
      (result (fold stx-transfer-fold-step
                    amounts
                    { idx: u0, recipients: recipients, ok: true, sender: sender }))
    )
      ;; Ensure all transfers succeeded
      (asserts! (get ok result) ERR_TRANSFER_FAILED)

      ;; Emit event
      (print {
        event: "stx-dispersed",
        sender: sender,
        total: total,
        count: recipients-len
      })

      (ok { total: total, count: recipients-len }))))

;; Disperse SIP-010 tokens from tx-sender to multiple recipients
;; Note: Works with most SIP-010 tokens. Some tokens with strict sender checks
;; may require escrow mode instead.
;; @param token: SIP-010 token contract reference
;; @param recipients: list of recipient addresses (max 10 for direct mode)
;; @param amounts: list of amounts (must match recipients length)
(define-public (disperse-sip010
    (token <sip010-trait>)
    (recipients (list 10 principal))
    (amounts (list 10 uint)))
  (let (
    (recipients-len (len recipients))
    (amounts-len (len amounts))
    (total (fold + amounts u0))
    (sender tx-sender)
    (token-principal (contract-of token))
  )
    ;; Validate inputs
    (asserts! (is-eq recipients-len amounts-len) ERR_LEN_MISMATCH)
    (asserts! (> recipients-len u0) ERR_EMPTY_RECIPIENTS)

    ;; Execute up to 10 transfers explicitly (Clarity limitation: no trait in fold)
    (match (element-at? recipients u0)
      r0 (match (element-at? amounts u0)
           a0 (begin (asserts! (> a0 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (contract-call? token transfer a0 sender r0 none)))
           true)
      true)
    (match (element-at? recipients u1)
      r1 (match (element-at? amounts u1)
           a1 (begin (asserts! (> a1 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (contract-call? token transfer a1 sender r1 none)))
           true)
      true)
    (match (element-at? recipients u2)
      r2 (match (element-at? amounts u2)
           a2 (begin (asserts! (> a2 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (contract-call? token transfer a2 sender r2 none)))
           true)
      true)
    (match (element-at? recipients u3)
      r3 (match (element-at? amounts u3)
           a3 (begin (asserts! (> a3 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (contract-call? token transfer a3 sender r3 none)))
           true)
      true)
    (match (element-at? recipients u4)
      r4 (match (element-at? amounts u4)
           a4 (begin (asserts! (> a4 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (contract-call? token transfer a4 sender r4 none)))
           true)
      true)
    (match (element-at? recipients u5)
      r5 (match (element-at? amounts u5)
           a5 (begin (asserts! (> a5 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (contract-call? token transfer a5 sender r5 none)))
           true)
      true)
    (match (element-at? recipients u6)
      r6 (match (element-at? amounts u6)
           a6 (begin (asserts! (> a6 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (contract-call? token transfer a6 sender r6 none)))
           true)
      true)
    (match (element-at? recipients u7)
      r7 (match (element-at? amounts u7)
           a7 (begin (asserts! (> a7 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (contract-call? token transfer a7 sender r7 none)))
           true)
      true)
    (match (element-at? recipients u8)
      r8 (match (element-at? amounts u8)
           a8 (begin (asserts! (> a8 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (contract-call? token transfer a8 sender r8 none)))
           true)
      true)
    (match (element-at? recipients u9)
      r9 (match (element-at? amounts u9)
           a9 (begin (asserts! (> a9 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (contract-call? token transfer a9 sender r9 none)))
           true)
      true)

    ;; Emit event
    (print {
      event: "token-dispersed",
      sender: sender,
      token: token-principal,
      total: total,
      count: recipients-len
    })

    (ok { token: token-principal, total: total, count: recipients-len })))

;; Disperse SIP-010 tokens from contract balance (escrow mode)
;; For larger distributions (up to 200 recipients):
;; 1. User first transfers total tokens to this contract (via get-contract-principal)
;; 2. Owner calls this function to disperse from contract's balance
;; @param token: SIP-010 token contract
;; @param recipients: list of recipient addresses (max 200)
;; @param amounts: list of amounts
(define-public (disperse-sip010-escrow
    (token <sip010-trait>)
    (recipients (list 10 principal))
    (amounts (list 10 uint)))
  (let (
    (recipients-len (len recipients))
    (amounts-len (len amounts))
    (total (fold + amounts u0))
    (token-principal (contract-of token))
    (contract-addr (as-contract tx-sender))
  )
    ;; Only owner can disperse from contract escrow
    (asserts! (is-eq tx-sender (var-get owner)) ERR_NOT_OWNER)

    ;; Validate inputs
    (asserts! (is-eq recipients-len amounts-len) ERR_LEN_MISMATCH)
    (asserts! (> recipients-len u0) ERR_EMPTY_RECIPIENTS)

    ;; Execute transfers from contract balance (as-contract)
    (match (element-at? recipients u0)
      r0 (match (element-at? amounts u0)
           a0 (begin (asserts! (> a0 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (as-contract (contract-call? token transfer a0 tx-sender r0 none))))
           true)
      true)
    (match (element-at? recipients u1)
      r1 (match (element-at? amounts u1)
           a1 (begin (asserts! (> a1 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (as-contract (contract-call? token transfer a1 tx-sender r1 none))))
           true)
      true)
    (match (element-at? recipients u2)
      r2 (match (element-at? amounts u2)
           a2 (begin (asserts! (> a2 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (as-contract (contract-call? token transfer a2 tx-sender r2 none))))
           true)
      true)
    (match (element-at? recipients u3)
      r3 (match (element-at? amounts u3)
           a3 (begin (asserts! (> a3 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (as-contract (contract-call? token transfer a3 tx-sender r3 none))))
           true)
      true)
    (match (element-at? recipients u4)
      r4 (match (element-at? amounts u4)
           a4 (begin (asserts! (> a4 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (as-contract (contract-call? token transfer a4 tx-sender r4 none))))
           true)
      true)
    (match (element-at? recipients u5)
      r5 (match (element-at? amounts u5)
           a5 (begin (asserts! (> a5 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (as-contract (contract-call? token transfer a5 tx-sender r5 none))))
           true)
      true)
    (match (element-at? recipients u6)
      r6 (match (element-at? amounts u6)
           a6 (begin (asserts! (> a6 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (as-contract (contract-call? token transfer a6 tx-sender r6 none))))
           true)
      true)
    (match (element-at? recipients u7)
      r7 (match (element-at? amounts u7)
           a7 (begin (asserts! (> a7 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (as-contract (contract-call? token transfer a7 tx-sender r7 none))))
           true)
      true)
    (match (element-at? recipients u8)
      r8 (match (element-at? amounts u8)
           a8 (begin (asserts! (> a8 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (as-contract (contract-call? token transfer a8 tx-sender r8 none))))
           true)
      true)
    (match (element-at? recipients u9)
      r9 (match (element-at? amounts u9)
           a9 (begin (asserts! (> a9 u0) ERR_NON_POSITIVE_AMOUNT)
                     (try! (as-contract (contract-call? token transfer a9 tx-sender r9 none))))
           true)
      true)

    ;; Emit event
    (print {
      event: "token-dispersed-escrow",
      owner: tx-sender,
      token: token-principal,
      total: total,
      count: recipients-len
    })

    (ok { token: token-principal, total: total, count: recipients-len })))

;; ============================================
;; Read-Only Utilities
;; ============================================

;; Calculate total amount from a list (useful for UI pre-calculation)
(define-read-only (calculate-total (amounts (list 200 uint)))
  (sum-amounts amounts))

;; Get maximum supported recipients for STX disperse
(define-read-only (get-max-recipients-stx)
  MAX_RECIPIENTS)

;; Get maximum supported recipients for SIP-010 disperse
(define-read-only (get-max-recipients-sip010)
  u10)

;; Get contract version/name
(define-read-only (get-contract-name)
  CONTRACT_NAME)

```
