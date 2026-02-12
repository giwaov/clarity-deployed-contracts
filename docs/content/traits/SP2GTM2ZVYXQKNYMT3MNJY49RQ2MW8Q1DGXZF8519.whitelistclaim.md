---
title: "Trait whitelistclaim"
draft: true
---
```
;; title: whitelist-airdrop
;; summary: Allow specific addresses to claim a pre-set amount of STX.

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-WHITELISTED (err u402))
(define-constant ERR-ALREADY-CLAIMED (err u403))

;; Data Maps
;; Map: Principal -> { amount: uint, claimed: bool }
(define-map Whitelist principal { amount: uint, claimed: bool })

;; Public Functions

;; 1. Admin: Add a user to the whitelist
(define-public (add-to-whitelist (user principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set Whitelist user { amount: amount, claimed: false }))
  )
)

;; 2. Admin: Fund the airdrop
(define-public (deposit (amount uint))
  (stx-transfer? amount tx-sender (as-contract tx-sender))
)

;; 3. User: Claim your STX
(define-public (claim)
  (let
    (
      (entry (unwrap! (map-get? Whitelist tx-sender) ERR-NOT-WHITELISTED))
      (amount (get amount entry))
      (has-claimed (get claimed entry))
    )
    (begin
      (asserts! (not has-claimed) ERR-ALREADY-CLAIMED)
      ;; Mark as claimed first
      (map-set Whitelist tx-sender { amount: amount, claimed: true })
      ;; Send the STX
      (as-contract (stx-transfer? amount (as-contract tx-sender) tx-sender))
    )
  )
)

;; Read-only: Check claim status
(define-read-only (get-claim-status (user principal))
  (map-get? Whitelist user)
)

```
