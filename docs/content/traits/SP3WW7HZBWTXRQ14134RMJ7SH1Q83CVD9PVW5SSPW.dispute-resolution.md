---
title: "Trait dispute-resolution"
draft: true
---
```
;; Dispute Resolution

(define-constant contract-owner tx-sender)
(define-data-var next-dispute-id uint u1)

(define-map disputes uint { escrow-id: uint, resolved: bool, winner: (optional principal) })

(define-public (file-dispute (escrow-id uint))
  (let ((dispute-id (var-get next-dispute-id)))
    (map-set disputes dispute-id { escrow-id: escrow-id, resolved: false, winner: none })
    (var-set next-dispute-id (+ dispute-id u1))
    (ok dispute-id)
  )
)

(define-public (resolve-dispute (dispute-id uint) (winner principal))
  (let ((dispute (unwrap! (map-get? disputes dispute-id) (err u100))))
    (asserts! (is-eq tx-sender contract-owner) (err u101))
    (map-set disputes dispute-id (merge dispute { resolved: true, winner: (some winner) }))
    (ok true)
  )
)

```
