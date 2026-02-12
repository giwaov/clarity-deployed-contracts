---
title: "Trait fee-collector"
draft: true
---
```
;; Fee Collector Contract

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))

(define-data-var collected-fees uint u0)

(define-read-only (get-collected-fees)
  (var-get collected-fees)
)

(define-public (collect-fees (amount uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set collected-fees (+ (var-get collected-fees) amount))
    (ok amount)
  )
)

```
