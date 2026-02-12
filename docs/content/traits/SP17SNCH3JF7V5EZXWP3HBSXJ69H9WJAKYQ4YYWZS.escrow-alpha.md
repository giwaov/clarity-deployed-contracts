---
title: "Trait escrow-alpha"
draft: true
---
```
;; Escrow contract for trustless payments
(define-map escrows {id: uint} {buyer: principal, seller: principal, amount: uint, completed: bool})
(define-data-var escrow-count uint u0)

(define-read-only (get-escrow (id uint))
  (map-get? escrows {id: id})
)

(define-public (create-escrow (seller principal) (amount uint))
  (let ((id (var-get escrow-count)))
    (begin
      (map-set escrows {id: id} {
        buyer: tx-sender,
        seller: seller,
        amount: amount,
        completed: false
      })
      (ok (var-set escrow-count (+ id u1)))
    )
  )
)

(define-public (complete-escrow (id uint))
  (let ((escrow (unwrap! (map-get? escrows {id: id}) (err u1))))
    (begin
      (asserts! (is-eq tx-sender (get buyer escrow)) (err u2))
      (map-set escrows {id: id} (merge escrow {completed: true}))
      (ok true)
    )
  )
)

```
