---
title: "Trait conserve-v2"
draft: true
---
```
;; Conservation Fund Smart Contract
;; This contract manages donations and fund distribution for conservation efforts
;; Clarity Version: 2
;; Author: Conserve Team

;; Error Constants
(define-constant ERR_NOT_AUTHORIZED (err u100)) ;;; Unauthorized access
(define-constant ERR_INVALID_AMOUNT (err u101)) ;;; Amount is 0 or invalid
(define-constant ERR_MIN_DONATION (err u102)) ;;; Amount below minimum

;; Data Variables
(define-data-var fund-balance uint u0) ;;; Tracks total fund balance
(define-data-var contract-owner principal tx-sender) ;;; The current contract administrator
(define-data-var min-donation uint u1) ;;; Minimum donation amount allowed
(define-constant CONTRACT_PRINCIPAL tx-sender)

;; Map to track individual donor contributions
(define-map donors principal uint)

;; Read-only: Get total donation for a specific address
(define-read-only (get-donation (who principal))
  (ok (default-to u0 (map-get? donors who)))
)

;; Read-only: Get the minimum donation amount
(define-read-only (get-min-donation)
  (ok (var-get min-donation))
)

;; Read-only: Get the current contract owner
(define-read-only (get-owner)
  (ok (var-get contract-owner))
)

;; Read-only: Get the current fund balance
(define-read-only (get-balance)
  (ok (var-get fund-balance))
)


;; Public: Deposit STX into the fund
;; @param amount: The amount of STX to deposit
(define-public (deposit (amount uint))
  (begin
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (asserts! (>= amount (var-get min-donation)) ERR_MIN_DONATION)
    (try! (stx-transfer? amount tx-sender CONTRACT_PRINCIPAL))
    (var-set fund-balance (+ (var-get fund-balance) amount))
    (map-set donors tx-sender (+ (default-to u0 (map-get? donors tx-sender)) amount))
    (print {event: "deposit", amount: amount, sender: tx-sender})
    (ok true)
  )
)

;; Public: Withdraw STX from the fund (Owner only)
;; @param amount: The amount of STX to withdraw
;; @param recipient: The address to receive the funds
(define-public (withdraw (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (<= amount (var-get fund-balance)) ERR_INVALID_AMOUNT)
    (asserts! (is-standard recipient) ERR_INVALID_AMOUNT)
    (try! (stx-transfer? amount tx-sender recipient))
    (var-set fund-balance (- (var-get fund-balance) amount))
    (print {event: "withdraw", amount: amount, recipient: recipient})
    (ok true)
  )
)

;; Public: Transfer ownership of the contract (Owner only)
;; @param new-owner: The address of the new owner
(define-public (set-owner (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (is-standard new-owner) ERR_NOT_AUTHORIZED)
    (var-set contract-owner new-owner)
    (print {event: "set-owner", new-owner: new-owner})
    (ok true)
  )
)

;; Public: Set the minimum donation amount (Owner only)
;; @param amount: The new minimum donation amount
(define-public (set-min-donation (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_AMOUNT)
    (var-set min-donation amount)
    (print {event: "set-min-donation", amount: amount})
    (ok true)
  )
)

```
