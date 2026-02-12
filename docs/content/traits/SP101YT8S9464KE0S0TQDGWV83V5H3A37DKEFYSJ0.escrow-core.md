---
title: "Trait escrow-core"
draft: true
---
```
;; Simple Escrow Core
(define-constant ERR-NOT-FOUND (err u100))
(define-constant ERR-UNAUTHORIZED (err u101))

(define-map escrows uint {buyer: principal, seller: principal, amount: uint, funded: bool})
(define-data-var last-id uint u0)

(define-public (create-escrow (seller principal) (amount uint))
  (let ((id (+ (var-get last-id) u1)))
    (map-set escrows id {buyer: tx-sender, seller: seller, amount: amount, funded: false})
    (var-set last-id id)
    (ok id)))

(define-read-only (get-escrow (id uint))
  (map-get? escrows id))

```
