---
title: "Trait token-v6"
draft: true
---
```
;; Simple Token V6
(define-fungible-token simple-token-6)

(define-public (mint (amount uint))
  (ft-mint? simple-token-6 amount tx-sender))

(define-public (transfer (amount uint) (recipient principal))
  (ft-transfer? simple-token-6 amount tx-sender recipient))

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance simple-token-6 account)))
```
