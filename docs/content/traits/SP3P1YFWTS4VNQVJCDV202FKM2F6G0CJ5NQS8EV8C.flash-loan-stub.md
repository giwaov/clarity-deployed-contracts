---
title: "Trait flash-loan-stub"
draft: true
---
```
;; flash-loan-stub.clar
;; Mock Flash Loan Interface
;; Flash Loan User Trait Definition
(define-trait flash-loan-user-trait
    (
        (execute-flash-loan (uint) (response bool uint))
    )
)

(define-constant FEE_BASIS_POINTS u10) ;; 0.1%

(define-public (flash-loan (amount uint) (recipient <flash-loan-user-trait>))
    (let
        (
            (fee (/ (* amount FEE_BASIS_POINTS) u10000))
            (total-repay (+ amount fee))
            (pre-bal (stx-get-balance (as-contract tx-sender)))
        )
        (try! (as-contract (stx-transfer? amount tx-sender (contract-of recipient))))
        (try! (contract-call? recipient execute-flash-loan amount))
        
        (asserts! (>= (stx-get-balance (as-contract tx-sender)) (+ pre-bal fee)) (err u100))
        (ok true)
    )
)

```
