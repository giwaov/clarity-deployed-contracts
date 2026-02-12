---
title: "Trait jar"
draft: true
---
```
;; Contract: Tip Jar
;; Description: Collects donations and tracks the top donor.

(define-data-var top-donor principal tx-sender)
(define-data-var top-amount uint u0)

(define-public (tip (amount uint))
    (begin
        ;; Transfer STX from sender to contract owner (or this contract)
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        
        ;; Update top donor if amount is higher
        (if (> amount (var-get top-amount))
            (begin
                (var-set top-donor tx-sender)
                (var-set top-amount amount)
                (ok "New Top Donor!")
            )
            (ok "Thank you for the tip")
        )
    )
)

(define-read-only (get-top-donor)
    (ok { user: (var-get top-donor), amount: (var-get top-amount) })
)
```
