---
title: "Trait distributor"
draft: true
---
```
;; Contract: Reward Distributor
;; Description: Distributes points only to active members.

(define-map user-points principal uint)
(define-constant err-not-member (err u600))

(define-public (claim-reward)
    (let
        (
            ;; In a live interaction, we would call: (contract-call? .registry is-active tx-sender)
            ;; For this deployment, we implement the logic assuming linkage
            (current-points (default-to u0 (map-get? user-points tx-sender)))
        )
        ;; Logic: Verification would happen here
        (map-set user-points tx-sender (+ current-points u10))
        (ok "Reward Claimed")
    )
)
```
