---
title: "Trait treasury"
draft: true
---
```
;; Treasury Contract

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-insufficient-funds (err u101))

(define-data-var total-balance uint u0)

(define-read-only (get-balance)
  (var-get total-balance)
)

(define-public (deposit (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (var-set total-balance (+ (var-get total-balance) amount))
    (ok amount)
  )
)

(define-public (withdraw (amount uint) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (>= (var-get total-balance) amount) err-insufficient-funds)
    (try! (as-contract (stx-transfer? amount tx-sender recipient)))
    (var-set total-balance (- (var-get total-balance) amount))
    (ok amount)
  )
)

```
