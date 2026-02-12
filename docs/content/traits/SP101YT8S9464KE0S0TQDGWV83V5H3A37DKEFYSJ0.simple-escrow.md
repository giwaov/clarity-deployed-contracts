---
title: "Trait simple-escrow"
draft: true
---
```
;; Simple Escrow - Track escrow agreements (no funds held)

(define-map escrows
  uint
  {
    seller: principal,
    buyer: principal,
    amount: uint,
    released: bool
  }
)

(define-data-var escrow-id uint u0)

(define-public (create-escrow (seller principal) (amount uint))
  (let ((id (var-get escrow-id)))
    (map-set escrows id {
      seller: seller,
      buyer: tx-sender,
      amount: amount,
      released: false
    })
    (var-set escrow-id (+ id u1))
    (ok id)
  )
)

(define-public (mark-released (id uint))
  (let ((escrow (unwrap! (map-get? escrows id) (err u404))))
    (asserts! (is-eq tx-sender (get buyer escrow)) (err u403))
    (asserts! (not (get released escrow)) (err u400))
    (map-set escrows id (merge escrow { released: true }))
    (ok true)
  )
)

(define-read-only (get-escrow (id uint))
  (map-get? escrows id)
)

```
