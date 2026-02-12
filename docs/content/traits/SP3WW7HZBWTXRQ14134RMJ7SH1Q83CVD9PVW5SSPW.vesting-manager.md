---
title: "Trait vesting-manager"
draft: true
---
```
;; Vesting Manager

(define-map vesting-schedules principal { total: uint, released: uint, start: uint, duration: uint })

(define-public (create-vesting (beneficiary principal) (total uint) (duration uint))
  (begin
    (map-set vesting-schedules beneficiary { total: total, released: u0, start: block-height, duration: duration })
    (ok true)
  )
)

```
