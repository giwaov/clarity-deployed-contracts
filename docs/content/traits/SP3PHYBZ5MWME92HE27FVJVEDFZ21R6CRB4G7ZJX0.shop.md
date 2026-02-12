---
title: "Trait shop"
draft: true
---
```
;; Contract: Gift Shop
;; Description: Exchange points for items.

(define-constant gift-price u500)

(define-public (buy-gift)
    (begin
        ;; Burn points from user (calls the Token contract)
        ;; User must approve this contract first in real scenario, 
        ;; but for this demo we assume direct burn access or self-burn.
        (contract-call? .points burn gift-price tx-sender)
    )
)
```
