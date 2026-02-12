---
title: "Trait escrow-service"
draft: true
---
```
;; Escrow Service

(define-map escrows uint { buyer: principal, seller: principal, amount: uint, released: bool })
(define-data-var next-escrow-id uint u1)

(define-public (create-escrow (seller principal) (amount uint))
  (let ((escrow-id (var-get next-escrow-id)))
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set escrows escrow-id { buyer: tx-sender, seller: seller, amount: amount, released: false })
    (var-set next-escrow-id (+ escrow-id u1))
    (ok escrow-id)
  )
)

(define-public (release-escrow (escrow-id uint))
  (let ((escrow (unwrap! (map-get? escrows escrow-id) (err u100))))
    (asserts! (is-eq tx-sender (get buyer escrow)) (err u101))
    (try! (as-contract (stx-transfer? (get amount escrow) tx-sender (get seller escrow))))
    (map-set escrows escrow-id (merge escrow { released: true }))
    (ok true)
  )
)

```
