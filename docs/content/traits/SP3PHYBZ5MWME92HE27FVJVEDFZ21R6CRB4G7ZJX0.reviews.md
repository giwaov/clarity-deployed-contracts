---
title: "Trait reviews"
draft: true
---
```
;; Contract: Reviews
;; Description: Users rate items from 1 to 5.

(define-map ratings { item-id: uint, user: principal } uint)

(define-public (rate-item (id uint) (stars uint))
    (let
        (
            ;; Verify item exists in the registry contract
            (exists (unwrap-panic (contract-call? .items item-exists id)))
        )
        ;; Validation
        (asserts! exists (err u404))
        (asserts! (and (>= stars u1) (<= stars u5)) (err u400))
        
        ;; Save rating
        (map-set ratings { item-id: id, user: tx-sender } stars)
        (ok "Rating Submitted")
    )
)

(define-read-only (get-my-rating (id uint) (user principal))
    (ok (map-get? ratings { item-id: id, user: user }))
)
```
