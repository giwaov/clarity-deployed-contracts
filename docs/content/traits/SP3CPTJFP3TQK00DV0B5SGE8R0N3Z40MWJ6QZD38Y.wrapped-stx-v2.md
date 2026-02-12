---
title: "Trait wrapped-stx-v2"
draft: true
---
```
;; wrapped-stx.clar
;; 1:1 STX wrapper

(define-fungible-token wstx)

(define-public (wrap (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (ft-mint? wstx amount tx-sender)
    )
)

(define-public (unwrap (amount uint))
    (begin
        (try! (ft-burn? wstx amount tx-sender))
        (as-contract (stx-transfer? amount tx-sender tx-sender))
    )
)

```
