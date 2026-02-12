---
title: "Trait token-v7"
draft: true
---
```
;; Simple Token V7
(define-fungible-token simple-token-7)

(define-public (mint (amount uint))
  (ft-mint? simple-token-7 amount tx-sender))

(define-public (transfer (amount uint) (recipient principal))
  (ft-transfer? simple-token-7 amount tx-sender recipient))

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance simple-token-7 account)))
```
