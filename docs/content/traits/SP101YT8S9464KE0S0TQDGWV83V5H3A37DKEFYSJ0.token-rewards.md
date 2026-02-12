---
title: "Trait token-rewards"
draft: true
---
```
;; Token Rewards - Simple token rewards

(define-map token-balances
  principal
  { balance: uint }
)

(define-public (mint-tokens (user principal) (amount uint))
  (let ((current (default-to u0 (get balance (map-get? token-balances user)))))
    (map-set token-balances user { balance: (+ current amount) })
    (ok true)
  )
)

(define-public (burn-tokens (amount uint))
  (let ((current (default-to u0 (get balance (map-get? token-balances tx-sender)))))
    (asserts! (>= current amount) (err u400))
    (map-set token-balances tx-sender { balance: (- current amount) })
    (ok true)
  )
)

(define-read-only (get-balance (user principal))
  (default-to u0 (get balance (map-get? token-balances user)))
)

```
