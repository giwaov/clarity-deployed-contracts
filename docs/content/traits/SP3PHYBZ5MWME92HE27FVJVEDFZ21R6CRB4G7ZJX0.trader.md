---
title: "Trait trader"
draft: true
---
```
;; Contract: Trader Bot
;; Description: Acts based on data from the Oracle.

(define-public (execute-strategy)
    (let
        (
            ;; Call the oracle contract to get current price
            (current-price (unwrap-panic (contract-call? .price-feed get-price)))
        )
        (if (> current-price u50000)
            (ok "Signal: SELL (Price is High)")
            (ok "Signal: BUY (Price is Low)")
        )
    )
)
```
