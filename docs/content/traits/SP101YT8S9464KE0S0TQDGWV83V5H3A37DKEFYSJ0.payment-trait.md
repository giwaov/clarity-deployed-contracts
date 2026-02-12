---
title: "Trait payment-trait"
draft: true
---
```
;; payment-trait.clar
;; Trait for payment processing in ClearDeal
;; Supports different payment methods and fee structures

(define-trait payment-trait
  (
    ;; Process payment from buyer to escrow
    (process-payment (principal uint uint) (response bool uint))

    ;; Release payment to seller
    (release-payment (principal uint uint) (response bool uint))

    ;; Refund payment to buyer
    (refund-payment (principal uint uint) (response bool uint))

    ;; Split payment between parties
    (split-payment (principal principal uint uint uint) (response bool uint))

    ;; Calculate platform fee
    (calculate-fee (uint) (response uint uint))

    ;; Withdraw accumulated fees (admin only)
    (withdraw-fees (principal uint) (response bool uint))

    ;; Get payment details
    (get-payment-info (uint) (response {
      amount: uint,
      fee: uint,
      total: uint,
      status: (string-ascii 20)
    } uint))

    ;; Check if payment is locked
    (is-locked (uint) (response bool uint))
  )
)

```
