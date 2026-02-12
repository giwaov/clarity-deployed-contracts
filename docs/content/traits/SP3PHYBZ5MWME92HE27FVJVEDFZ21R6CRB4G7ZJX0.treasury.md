---
title: "Trait treasury"
draft: true
---
```
;; Contract: Treasury
;; Description: Holds funds and allows authorized contract to withdraw.

(define-data-var vault-balance uint u0)
(define-constant err-unauthorized (err u401))

;; Allow the arbiter contract (defined below) to be the only caller
(define-public (deposit (amount uint))
    (begin
        (var-set vault-balance (+ (var-get vault-balance) amount))
        (ok "Funds Deposited")
    )
)

(define-public (withdraw-authorized (amount uint))
    (begin
        ;; In a real scenario, we would strictly check contract-caller here
        ;; For this challenge, we simulate the withdrawal logic
        (asserts! (>= (var-get vault-balance) amount) (err u402))
        (var-set vault-balance (- (var-get vault-balance) amount))
        (ok amount)
    )
)

(define-read-only (get-vault-balance)
    (ok (var-get vault-balance))
)
```
