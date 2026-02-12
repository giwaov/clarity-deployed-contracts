---
title: "Trait mixer-trait"
draft: true
---
```
;; Mixer Trait Definition
(define-trait mixer-trait
  (
    ;; Deposit funds into the mixer
    ;; Args: commitment (hash), pool-amount
    (deposit ((buff 32) uint) (response { commitment: (buff 32), pool-amount: uint } uint))

    ;; Withdraw funds from the mixer
    ;; Args: nullifier, recipient, pool-amount, commitment
    (withdraw ((buff 32) principal uint (buff 32)) (response { recipient: principal, amount: uint, fee: uint, nullifier: (buff 32) } uint))
  )
)

```
