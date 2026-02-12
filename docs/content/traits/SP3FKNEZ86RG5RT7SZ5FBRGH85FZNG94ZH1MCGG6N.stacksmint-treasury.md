---
title: "Trait stacksmint-treasury"
draft: true
---
```
;; StacksMint Treasury Contract
;; Manages creator fees collection and withdrawal
;; Creator Fee: 0.01 STX (10000 microSTX)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))
(define-constant ERR-TRANSFER-FAILED (err u102))
(define-constant CREATOR-FEE u10000) ;; 0.01 STX in microSTX

;; Data Variables
(define-data-var total-fees-collected uint u0)
(define-data-var total-fees-withdrawn uint u0)

;; Data Maps
(define-map authorized-contracts principal bool)

;; Read-only functions

;; Get creator fee amount
(define-read-only (get-creator-fee)
  CREATOR-FEE
)

;; Get total fees collected
(define-read-only (get-total-fees-collected)
  (var-get total-fees-collected)
)

;; Get total fees withdrawn
(define-read-only (get-total-fees-withdrawn)
  (var-get total-fees-withdrawn)
)

;; Get treasury balance
(define-read-only (get-treasury-balance)
  (stx-get-balance (as-contract tx-sender))
)

;; Check if contract is authorized
(define-read-only (is-authorized-contract (contract principal))
  (default-to false (map-get? authorized-contracts contract))
)

;; Public functions

;; Deposit fee to treasury (called by other StacksMint contracts)
(define-public (deposit-fee (sender principal))
  (begin
    (try! (stx-transfer? CREATOR-FEE sender (as-contract tx-sender)))
    (var-set total-fees-collected (+ (var-get total-fees-collected) CREATOR-FEE))
    (ok true)
  )
)

;; Authorize a contract to interact with treasury
(define-public (authorize-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-set authorized-contracts contract true)
    (ok true)
  )
)

;; Revoke contract authorization
(define-public (revoke-contract (contract principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (map-delete authorized-contracts contract)
    (ok true)
  )
)

;; Withdraw fees to creator (owner only)
(define-public (withdraw-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= amount (get-treasury-balance)) ERR-INSUFFICIENT-BALANCE)
    (try! (as-contract (stx-transfer? amount tx-sender CONTRACT-OWNER)))
    (var-set total-fees-withdrawn (+ (var-get total-fees-withdrawn) amount))
    (ok amount)
  )
)

;; Withdraw all fees to creator (owner only)
(define-public (withdraw-all-fees)
  (let ((balance (get-treasury-balance)))
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (> balance u0) ERR-INSUFFICIENT-BALANCE)
    (try! (as-contract (stx-transfer? balance tx-sender CONTRACT-OWNER)))
    (var-set total-fees-withdrawn (+ (var-get total-fees-withdrawn) balance))
    (ok balance)
  )
)

```
