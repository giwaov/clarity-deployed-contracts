---
title: "Trait Tokensito"
draft: true
---
```
;; basic-token.clar
;; Clarity 3 compatible

(define-fungible-token basic-token)

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INSUFFICIENT-BALANCE (err u101))

;; Solo el deployer puede mintear
(define-constant CONTRACT-OWNER tx-sender)

;; Leer balance
(define-read-only (get-balance (who principal))
  (ft-get-balance basic-token who)
)

;; Mint inicial
(define-public (mint (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ft-mint? basic-token amount recipient)
  )
)

;; Transferencia
(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (begin
    (asserts!
      (>= (ft-get-balance basic-token sender) amount)
      ERR-INSUFFICIENT-BALANCE
    )
    (ft-transfer? basic-token amount sender recipient)
  )
)

```
