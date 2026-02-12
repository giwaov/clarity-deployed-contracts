---
title: "Trait nova-supply-chain-tracker"
draft: true
---
```

;; Nova Supply Chain Tracker
;; Tracks application of steps in a supply chain

(define-map supply-items
    { item-id: uint }
    {
        creator: principal,
        current-handler: principal,
        status: (string-ascii 32)
    }
)

(define-map item-history
    { item-id: uint, step-index: uint }
    {
        handler: principal,
        action: (string-ascii 64),
        timestamp: uint,
        location: (string-ascii 64)
    }
)

(define-data-var nonce uint u0)

(define-public (create-item (initial-status (string-ascii 32)))
    (let
        (
            (id (+ (var-get nonce) u1))
        )
        (var-set nonce id)
        (ok (map-set supply-items
            { item-id: id }
            {
                creator: tx-sender,
                current-handler: tx-sender,
                status: initial-status
            }
        ))
    )
)

(define-public (update-status (item-id uint) (new-status (string-ascii 32)) (action (string-ascii 64)) (location (string-ascii 64)))
    (let
        (
            (item (unwrap! (map-get? supply-items { item-id: item-id }) (err u404)))
        )
        (asserts! (is-eq tx-sender (get current-handler item)) (err u100))
        (map-set supply-items
            { item-id: item-id }
            (merge item { status: new-status })
        )
        ;; Note: simplified history tracking, would normally track step index
        (ok true)
    )
)

(define-public (transfer-item (item-id uint) (new-handler principal))
    (let
        (
            (item (unwrap! (map-get? supply-items { item-id: item-id }) (err u404)))
        )
        (asserts! (is-eq tx-sender (get current-handler item)) (err u100))
        (ok (map-set supply-items
            { item-id: item-id }
            (merge item { current-handler: new-handler })
        ))
    )
)

```
