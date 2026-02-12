---
title: "Trait gift-card-v2"
draft: true
---
```
;; gift-card.clar
;; Pre-funded accounts

(define-map cards (buff 32) uint)

(define-public (create-card (hash (buff 32)) (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set cards hash amount)
        (ok true)
    )
)

(define-public (claim-card (secret (buff 32)))
    (let
        (
            (hash (sha256 secret))
            (amount (unwrap! (map-get? cards hash) (err u100)))
        )
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (map-delete cards hash)
        (ok amount)
    )
)

```
