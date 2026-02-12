---
title: "Trait points-system"
draft: true
---
```
;; Points System - Award and track points

(define-map points { user: principal } { balance: uint })

(define-public (award-points (user principal) (amount uint))
  (let ((current (default-to u0 (get balance (map-get? points { user: user })))))
    (map-set points { user: user } { balance: (+ current amount) })
    (ok true)
  )
)

(define-public (spend-points (amount uint))
  (let ((current (default-to u0 (get balance (map-get? points { user: tx-sender })))))
    (asserts! (>= current amount) (err u400))
    (map-set points { user: tx-sender } { balance: (- current amount) })
    (ok true)
  )
)

(define-read-only (get-points (user principal))
  (default-to u0 (get balance (map-get? points { user: user })))
)

```
