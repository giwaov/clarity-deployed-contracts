---
title: "Trait battle-arena"
draft: true
---
```
;; Contract: Battle Arena
;; Description: Logic for fighting and gaining XP.

(define-public (fight-monster)
    (begin
        ;; Logic: Determine win/loss (simulated as always win here)
        ;; Call the stats contract to reward the player
        ;; Note: In a real app, we check contract-caller strictly
        (as-contract (contract-call? .hero-stats add-xp tx-sender u50))
    )
)

(define-public (train-hero)
    (begin
        (as-contract (contract-call? .hero-stats add-xp tx-sender u10))
    )
)
```
