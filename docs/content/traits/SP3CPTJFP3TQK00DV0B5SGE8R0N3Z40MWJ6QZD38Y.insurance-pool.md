---
title: "Trait insurance-pool"
draft: true
---
```
;; insurance-pool.clar
;; Shared risk pool

(define-data-var pool-balance uint u0)
(define-map claims uint { info: (string-utf8 100), approved: bool })

(define-public (pay-premium (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (var-set pool-balance (+ (var-get pool-balance) amount))
        (ok true)
    )
)

(define-public (get-claim (id uint))
    (ok (map-get? claims id))
)

(define-public (file-claim (id uint) (info (string-utf8 100)))
    (ok (map-set claims id { info: info, approved: false }))
)

```
