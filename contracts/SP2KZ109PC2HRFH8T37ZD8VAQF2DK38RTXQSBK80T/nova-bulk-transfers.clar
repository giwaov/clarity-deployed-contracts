
;; nova-bulk-transfers.clar
;; A Clarity 2 contract for batch STX and Nova Fungible Token transfers.

;; ============================================
;; Constants
;; ============================================
(define-constant MAX_RECIPIENTS u50)
(define-constant ERR_EXCEED_MAX (err u100))
(define-constant ERR_TRANSFER_FAILED (err u101))
(define-constant ERR_NOT_CONTRACT (err u102))
(define-constant ERR_ZERO_AMOUNT (err u103))

;; ============================================
;; STX Multisend
;; ============================================

;; Private: Performs a single STX transfer
(define-private (send-stx-single (recipient {
  to: principal,
  ustx: uint,
}))
  (stx-transfer? (get ustx recipient) tx-sender (get to recipient))
)

;; Private: Fold helper for STX - accumulates results and performs transfers
(define-private (fold-stx-transfer
    (recipient {
      to: principal,
      ustx: uint,
    })
    (prev-result (response bool uint))
  )
  (match prev-result
    success (send-stx-single recipient)
    error (err error)
  )
)

;; Private: Calculate total STX amount
(define-private (sum-ustx
    (entry {
      to: principal,
      ustx: uint,
    })
    (acc uint)
  )
  (+ acc (get ustx entry))
)

;; Public: Send STX to multiple recipients
(define-public (send-many-stx (recipients (list 50 {
  to: principal,
  ustx: uint,
})))
  (let (
      (count (len recipients))
      (total-ustx (fold sum-ustx recipients u0))
    )
    ;; Validate inputs
    (asserts! (<= count MAX_RECIPIENTS) ERR_EXCEED_MAX)
    (asserts! (> total-ustx u0) ERR_ZERO_AMOUNT)

    ;; Execute transfers
    (let ((transfer-result (fold fold-stx-transfer recipients (ok true))))
      (ok true)
    )
  )
)

;; ============================================
;; FT Multisend (Nova Fungible Tokens)
;; ============================================

;; Use trait for Nova Fungible Tokens
(use-trait nova-trait-fungible .nova-trait-fungible.nova-trait-fungible)

;; Private: Calculate total FT amount
(define-private (sum-ft-amount
    (entry {
      to: principal,
      amount: uint,
    })
    (acc uint)
  )
  (+ acc (get amount entry))
)

;; Public: Send FT to multiple recipients
;; Due to Clarity's fold limitations with traits, we handle up to 10 recipients inline
;; For more recipients, call this function multiple times
(define-public (send-many-ft
    (token-contract <nova-trait-fungible>)
    (recipients (list 10 {
      to: principal,
      amount: uint,
    }))
  )
  (let (
      (count (len recipients))
      (total-amount (fold sum-ft-amount recipients u0))
      (token-principal (contract-of token-contract))
    )
    ;; Validate
    (asserts! (<= count u10) ERR_EXCEED_MAX)
    (asserts! (> total-amount u0) ERR_ZERO_AMOUNT)
    
    ;; Execute transfers - unrolled loop for up to 10 recipients
    (transfer-ft-recipients token-contract recipients)
  )
)

;; Private: Transfer to list of recipients (unrolled)
(define-private (transfer-ft-recipients
    (token <nova-trait-fungible>)
    (recipients (list 10 {
      to: principal,
      amount: uint,
    }))
  )
  (let (
      (r0 (element-at? recipients u0))
      (r1 (element-at? recipients u1))
      (r2 (element-at? recipients u2))
      (r3 (element-at? recipients u3))
      (r4 (element-at? recipients u4))
      (r5 (element-at? recipients u5))
      (r6 (element-at? recipients u6))
      (r7 (element-at? recipients u7))
      (r8 (element-at? recipients u8))
      (r9 (element-at? recipients u9))
    )
    ;; Transfer to each recipient if present
    (and
      (match r0
        recipient (is-ok (contract-call? token transfer (get amount recipient) tx-sender
          (get to recipient) none
        ))
        true
      )
      (match r1
        recipient (is-ok (contract-call? token transfer (get amount recipient) tx-sender
          (get to recipient) none
        ))
        true
      )
      (match r2
        recipient (is-ok (contract-call? token transfer (get amount recipient) tx-sender
          (get to recipient) none
        ))
        true
      )
      (match r3
        recipient (is-ok (contract-call? token transfer (get amount recipient) tx-sender
          (get to recipient) none
        ))
        true
      )
      (match r4
        recipient (is-ok (contract-call? token transfer (get amount recipient) tx-sender
          (get to recipient) none
        ))
        true
      )
      (match r5
        recipient (is-ok (contract-call? token transfer (get amount recipient) tx-sender
          (get to recipient) none
        ))
        true
      )
      (match r6
        recipient (is-ok (contract-call? token transfer (get amount recipient) tx-sender
          (get to recipient) none
        ))
        true
      )
      (match r7
        recipient (is-ok (contract-call? token transfer (get amount recipient) tx-sender
          (get to recipient) none
        ))
        true
      )
      (match r8
        recipient (is-ok (contract-call? token transfer (get amount recipient) tx-sender
          (get to recipient) none
        ))
        true
      )
      (match r9
        recipient (is-ok (contract-call? token transfer (get amount recipient) tx-sender
          (get to recipient) none
        ))
        true
      )
    )
    (ok true)
  )
)

;; ============================================
;; Read-only functions
;; ============================================

;; Get the maximum number of recipients allowed
(define-read-only (get-max-recipients)
  MAX_RECIPIENTS
)
