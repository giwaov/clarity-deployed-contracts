---
title: "Trait oracle-resolver"
draft: true
---
```
;; Oracle Resolver Contract

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))

(define-map market-outcomes uint uint)

(define-read-only (get-outcome (market-id uint))
  (map-get? market-outcomes market-id)
)

(define-public (resolve-market (market-id uint) (outcome uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set market-outcomes market-id outcome)
    (ok true)
  )
)

```
