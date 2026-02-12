---
title: "Trait vault"
draft: true
---
```
;; Mini Vault Storage
(define-map user-balance principal uint)

(define-read-only (get-balance (user principal))
    (default-to u0 (map-get? user-balance user))
)

(define-public (record-deposit (amount uint))
    (let 
        (
            (current-bal (get-balance tx-sender))
        )
        (ok (map-set user-balance tx-sender (+ current-bal amount)))
    )
)
```
