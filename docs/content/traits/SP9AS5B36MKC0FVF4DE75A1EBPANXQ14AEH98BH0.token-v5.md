---
title: "Trait token-v5"
draft: true
---
```
;; Simple Token V5
(define-fungible-token simple-token-5)

(define-public (mint (amount uint))
  (ft-mint? simple-token-5 amount tx-sender))

(define-public (transfer (amount uint) (recipient principal))
  (ft-transfer? simple-token-5 amount tx-sender recipient))

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance simple-token-5 account)))
```
