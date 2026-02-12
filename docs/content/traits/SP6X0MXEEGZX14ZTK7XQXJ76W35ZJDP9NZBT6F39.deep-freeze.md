---
title: "Trait deep-freeze"
draft: true
---
```
;; Contract Name: deep-freeze
;; Description: Standard Clarity 2. Owner-only withdraw.

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u300))

(define-public (freeze (amount uint))
    (let
        (
            (vault (as-contract tx-sender))
        )
        ;; Anyone can deposit (User -> Vault)
        (stx-transfer? amount tx-sender vault)
    )
)

(define-public (admin-withdraw (amount uint) (recipient principal))
    (begin
        ;; Only Owner can call this
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        
        ;; Contract sends funds to Recipient
        (as-contract (stx-transfer? amount tx-sender recipient))
    )
)

(define-read-only (get-vault-balance)
    (stx-get-balance (as-contract tx-sender))
)
```
