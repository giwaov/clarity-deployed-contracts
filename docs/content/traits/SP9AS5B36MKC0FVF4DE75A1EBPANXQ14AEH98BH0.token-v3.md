---
title: "Trait token-v3"
draft: true
---
```
;; Simple Token V3
(define-fungible-token simple-token-3)

(define-public (mint (amount uint))
  (ft-mint? simple-token-3 amount tx-sender))

(define-public (transfer (amount uint) (recipient principal))
  (ft-transfer? simple-token-3 amount tx-sender recipient))

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance simple-token-3 account)))
```
