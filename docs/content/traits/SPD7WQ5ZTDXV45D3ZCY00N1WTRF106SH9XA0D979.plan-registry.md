---
title: "Trait plan-registry"
draft: true
---
```
;; plan-registry.clar
;; Manages subscription plan definitions

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u300))
(define-constant err-not-found (err u301))
(define-constant err-already-exists (err u302))

;; Data Maps
(define-map plans
    uint  ;; plan-id
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        price-per-block: uint,
        features: (list 10 (string-ascii 50)),
        active: bool,
        created-at: uint
    }
)

(define-data-var next-plan-id uint u1)

;; Create new plan
(define-public (create-plan 
    (name (string-ascii 50))
    (description (string-ascii 200))
    (price-per-block uint)
    (features (list 10 (string-ascii 50)))
)
    (let (
        (plan-id (var-get next-plan-id))
    )
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        
        (map-set plans
            plan-id
            {
                name: name,
                description: description,
                price-per-block: price-per-block,
                features: features,
                active: true,
                created-at: stacks-block-height
            }
        )
        
        (var-set next-plan-id (+ plan-id u1))
        (ok plan-id)
    )
)

;; Update plan
(define-public (update-plan
    (plan-id uint)
    (name (string-ascii 50))
    (description (string-ascii 200))
    (price-per-block uint)
    (features (list 10 (string-ascii 50)))
)
    (let (
        (existing-plan (unwrap! (map-get? plans plan-id) err-not-found))
    )
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        
        (map-set plans
            plan-id
            (merge existing-plan {
                name: name,
                description: description,
                price-per-block: price-per-block,
                features: features
            })
        )
        (ok true)
    )
)

;; Deactivate plan
(define-public (deactivate-plan (plan-id uint))
    (let (
        (existing-plan (unwrap! (map-get? plans plan-id) err-not-found))
    )
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        (map-set plans plan-id (merge existing-plan { active: false }))
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-plan (plan-id uint))
    (ok (map-get? plans plan-id))
)

(define-read-only (get-next-plan-id)
    (ok (var-get next-plan-id))
)


```
