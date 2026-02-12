---
title: "Trait vault"
draft: true
---
```
;; Simple Vault Contract

;; Track each user's balance
(define-map balances principal uint)

;; Deposit STX into vault
(define-public (deposit (amount uint))
  (let
    (
      (current-balance (default-to u0 (map-get? balances tx-sender)))
    )
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set balances tx-sender (+ current-balance amount))
    (ok true)
  )
)

;; Withdraw STX from vault
(define-public (withdraw (amount uint))
  (let
    (
      (current-balance (default-to u0 (map-get? balances tx-sender)))
    )
    (asserts! (>= current-balance amount) (err u1))
    (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
    (map-set balances tx-sender (- current-balance amount))
    (ok true)
  )
)

;; Check balance
(define-read-only (get-balance (user principal))
  (default-to u0 (map-get? balances user))
)
```
