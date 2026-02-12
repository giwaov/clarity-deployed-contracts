---
title: "Trait nova-prediction-market"
draft: true
---
```

;; nova-prediction-market.clar
;; Betting on outcomes
;; CLARITY VERSION: 2

(define-map bets
    {market-id: uint, user: principal, outcome: bool}
    uint ;; amount
)

(define-public (place-bet (market-id uint) (outcome bool) (amount uint))
    (begin
        ;; Transfer logic omitted
        (map-set bets {market-id: market-id, user: tx-sender, outcome: outcome} amount)
        (ok true)
    )
)

```
