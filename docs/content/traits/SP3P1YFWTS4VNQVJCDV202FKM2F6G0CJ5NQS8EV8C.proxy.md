---
title: "Trait proxy"
draft: true
---
```
;; proxy.clar
;; Contract that forwards calls (conceptual) or acts as intermediary

(define-public (forward-payment (recipient principal))
    (let
        (
            (amount (stx-get-balance tx-sender))
        )
        (try! (stx-transfer? amount tx-sender recipient))
        (ok amount)
    )
)

```
