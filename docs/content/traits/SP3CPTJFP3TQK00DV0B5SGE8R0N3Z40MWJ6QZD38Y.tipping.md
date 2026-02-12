---
title: "Trait tipping"
draft: true
---
```
;; tipping.clar
;; Send tips to content creators

(define-public (tip (recipient principal) (amount uint) (content-id (buff 32)))
    (begin
        (try! (stx-transfer? amount tx-sender recipient))
        (print { event: "tip", from: tx-sender, to: recipient, amount: amount, content: content-id })
        (ok true)
    )
)

```
