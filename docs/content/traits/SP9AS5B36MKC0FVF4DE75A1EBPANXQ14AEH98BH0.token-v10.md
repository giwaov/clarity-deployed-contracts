---
title: "Trait token-v10"
draft: true
---
```
;; Simple Token V10
(define-fungible-token simple-token-10)

(define-public (mint (amount uint))
  (ft-mint? simple-token-10 amount tx-sender))

(define-public (transfer (amount uint) (recipient principal))
  (ft-transfer? simple-token-10 amount tx-sender recipient))

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance simple-token-10 account)))
```
