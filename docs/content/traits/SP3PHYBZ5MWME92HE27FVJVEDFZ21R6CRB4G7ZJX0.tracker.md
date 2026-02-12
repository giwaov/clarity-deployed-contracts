---
title: "Trait tracker"
draft: true
---
```
;; Contract: Item Tracker
;; Description: Registers items only from authorized factory.

(define-map items uint { name: (string-ascii 50), location: (string-ascii 50) })
(define-data-var item-count uint u0)

(define-constant err-unauthorized (err u401))

(define-public (register-item (name (string-ascii 50)))
    (let
        (
            ;; 1. Call the factory contract to check permission
            (is-allowed (unwrap-panic (contract-call? .factory is-authorized tx-sender)))
            (new-id (+ (var-get item-count) u1))
        )
        ;; 2. Stop if not authorized
        (asserts! is-allowed err-unauthorized)
        
        ;; 3. Register item
        (map-set items new-id { name: name, location: "Factory Floor" })
        (var-set item-count new-id)
        (ok new-id)
    )
)

(define-public (update-location (item-id uint) (new-loc (string-ascii 50)))
    (let
        (
            (item (unwrap! (map-get? items item-id) (err u404)))
        )
        (map-set items item-id (merge item { location: new-loc }))
        (ok "Location Updated")
    )
)
```
