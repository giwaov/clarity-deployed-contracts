---
title: "Trait reward-points"
draft: true
---
```
;; Reward Points

(define-map points
  principal
  { balance: uint }
)

(define-public (add-points (user principal) (amount uint))
  (let ((current (default-to { balance: u0 } (map-get? points user))))
    (map-set points user { balance: (+ (get balance current) amount) })
    (ok true)
  )
)

(define-public (spend-points (amount uint))
  (let ((current (unwrap! (map-get? points tx-sender) (err u404))))
    (asserts! (>= (get balance current) amount) (err u400))
    (map-set points tx-sender { balance: (- (get balance current) amount) })
    (ok true)
  )
)

(define-read-only (get-points (user principal))
  (default-to { balance: u0 } (map-get? points user))
)

```
