---
title: "Trait reward-distributor"
draft: true
---
```
;; Reward Distributor
;; Distributes gaming rewards

(define-constant contract-owner tx-sender)

(define-map pending-rewards principal uint)

(define-read-only (get-pending-rewards (player principal))
  (default-to u0 (map-get? pending-rewards player))
)

(define-public (distribute-reward (player principal) (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) (err u100))
    (map-set pending-rewards player (+ (get-pending-rewards player) amount))
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
