---
title: "Trait rewards-distributor"
draft: true
---
```
;; Rewards Distributor Contract

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))

(define-map pending-rewards principal uint)
(define-data-var reward-rate uint u100)

(define-read-only (get-pending-rewards (user principal))
  (default-to u0 (map-get? pending-rewards user))
)

(define-public (distribute-rewards (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok amount)
  )
)

(define-public (claim-rewards)
  (let ((rewards (get-pending-rewards tx-sender)))
    (asserts! (> rewards u0) (err u101))
    (try! (as-contract (stx-transfer? rewards tx-sender tx-sender)))
    (map-delete pending-rewards tx-sender)
    (ok rewards)
  )
)

```
