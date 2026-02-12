---
title: "Trait savedd"
draft: true
---
```
;; Simple Wallet Transfer Contract

;; Transfer STX to another wallet
(define-public (transfer-stx (amount uint) (recipient principal))
  (stx-transfer? amount tx-sender recipient)
)

;; Get wallet balance
(define-read-only (get-balance (wallet principal))
  (stx-get-balance wallet)
)
```
