---
title: "Trait nova-data-availability-oracle"
draft: true
---
```

;; Nova Data Availability Oracle
;; Verifies data availability for off-chain computation

(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-DUPLICATE-ENTRY (err u101))

(define-data-var oracle-owner principal tx-sender)

(define-map data-availability-proofs 
    { data-hash: (buff 32) }
    { 
        provider: principal, 
        block-height: uint,
        verified: bool
    }
)

(define-public (post-proof (data-hash (buff 32)))
    (let
        (
            (existing-proof (map-get? data-availability-proofs { data-hash: data-hash }))
        )
        (asserts! (is-none existing-proof) ERR-DUPLICATE-ENTRY)
        (ok (map-set data-availability-proofs 
            { data-hash: data-hash }
            { 
                provider: tx-sender,
                block-height: block-height,
                verified: true
            }
        ))
    )
)

(define-read-only (get-verification (data-hash (buff 32)))
    (map-get? data-availability-proofs { data-hash: data-hash })
)

```
