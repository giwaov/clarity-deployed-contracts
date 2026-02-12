---
title: "Trait blind-auction"
draft: true
---
```
;; blind-auction.clar
;; Commit-reveal auction

(define-map bids { auction: uint, user: principal } (buff 32))

(define-public (commit-bid (auction uint) (hash (buff 32)))
    (begin
        (asserts! (not (is-eq hash 0x)) (err u103))
        (ok (map-set bids { auction: auction, user: tx-sender } hash))
    )
)

(define-public (reveal-bid (auction uint) (amount uint) (salt (buff 32)))
    (let
        (
            (comm (unwrap! (map-get? bids { auction: auction, user: tx-sender }) (err u100)))
            (amount-buff (unwrap! (to-consensus-buff? amount) (err u101)))
            (verification (sha256 (concat amount-buff salt)))
        )
        (asserts! (is-eq comm verification) (err u102))
        (ok true)
    )
)

```
