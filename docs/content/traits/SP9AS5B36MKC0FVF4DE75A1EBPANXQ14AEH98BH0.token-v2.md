---
title: "Trait token-v2"
draft: true
---
```
;; Simple Token V2
(define-fungible-token simple-token-2)

(define-public (mint (amount uint))
  (ft-mint? simple-token-2 amount tx-sender))

(define-public (transfer (amount uint) (recipient principal))
  (ft-transfer? simple-token-2 amount tx-sender recipient))

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance simple-token-2 account)))
```
