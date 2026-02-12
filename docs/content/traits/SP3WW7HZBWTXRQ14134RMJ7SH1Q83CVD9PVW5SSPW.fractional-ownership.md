---
title: "Trait fractional-ownership"
draft: true
---
```
;; Fractional Ownership

(define-map ownership-shares { property-id: uint, owner: principal } uint)

(define-public (buy-shares (property-id uint) (shares uint))
  (begin
    (map-set ownership-shares { property-id: property-id, owner: tx-sender } 
      (+ (default-to u0 (map-get? ownership-shares { property-id: property-id, owner: tx-sender })) shares))
    (ok shares)
  )
)

```
