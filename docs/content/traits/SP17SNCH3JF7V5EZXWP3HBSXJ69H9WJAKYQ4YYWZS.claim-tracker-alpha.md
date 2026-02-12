---
title: "Trait claim-tracker-alpha"
draft: true
---
```
;; Claim tracking contract
(define-map claims {id: uint} {claimant: principal, amount: uint, claimed: bool, timestamp: uint})
(define-data-var claim-counter uint u0)

(define-read-only (get-claim (id uint))
  (map-get? claims {id: id})
)

(define-public (create-claim (amount uint))
  (let ((id (var-get claim-counter)))
    (begin
      (map-set claims {id: id} {
        claimant: tx-sender,
        amount: amount,
        claimed: false,
        timestamp: burn-block-height
      })
      (ok (var-set claim-counter (+ id u1)))
    )
  )
)

(define-public (process-claim (id uint))
  (let ((claim (unwrap! (map-get? claims {id: id}) (err u1))))
    (begin
      (asserts! (not (get claimed claim)) (err u2))
      (ok (map-set claims {id: id} (merge claim {claimed: true})))
    )
  )
)

```
