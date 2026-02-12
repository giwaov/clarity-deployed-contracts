---
title: "Trait risk-pool"
draft: true
---
```
;; Risk Pool

(define-data-var total-pool uint u0)
(define-map contributions principal uint)

(define-public (contribute (amount uint))
  (begin
    (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
    (map-set contributions tx-sender (+ (default-to u0 (map-get? contributions tx-sender)) amount))
    (var-set total-pool (+ (var-get total-pool) amount))
    (ok amount)
  )
)

```
