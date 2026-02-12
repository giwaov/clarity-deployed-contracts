---
title: "Trait bonding-curve"
draft: true
---
```
;; Bonding Curve Contract

(define-map token-supplies uint uint)

(define-read-only (get-price (token-id uint))
  (let ((supply (default-to u0 (map-get? token-supplies token-id))))
    (+ u1000 (* supply u10))
  )
)

(define-public (buy-tokens (token-id uint) (amount uint))
  (let ((price (get-price token-id)))
    (try! (stx-transfer? (* price amount) tx-sender (as-contract tx-sender)))
    (map-set token-supplies token-id (+ (default-to u0 (map-get? token-supplies token-id)) amount))
    (ok amount)
  )
)

(define-public (sell-tokens (token-id uint) (amount uint))
  (ok amount)
)

```
