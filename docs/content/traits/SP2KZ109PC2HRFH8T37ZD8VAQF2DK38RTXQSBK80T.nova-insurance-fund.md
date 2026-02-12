---
title: "Trait nova-insurance-fund"
draft: true
---
```

;; nova-insurance-fund.clar
;; Acts as a safety net for the protocol
;; CLARITY VERSION: 2

(define-constant ERR-NOT-ADMIN (err u100))

(define-data-var admin principal tx-sender)

(define-public (deposit-funds (amount uint))
    (stx-transfer? amount tx-sender (as-contract tx-sender))
)

(define-public (payout-claim (recipient principal) (amount uint))
    (begin
        (asserts! (is-eq tx-sender (var-get admin)) ERR-NOT-ADMIN)
        (as-contract (stx-transfer? amount tx-sender recipient))
    )
)

(define-read-only (get-balance)
    (stx-get-balance (as-contract tx-sender))
)

```
