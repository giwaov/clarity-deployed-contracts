---
title: "Trait bounty-board"
draft: true
---
```
;; bounty-board.clar
;; Post bounties for tasks

(define-map bounties uint { issuer: principal, amount: uint, claimant: (optional principal), completed: bool })

(define-public (post-bounty (id uint) (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (ok (map-set bounties id { issuer: tx-sender, amount: amount, claimant: none, completed: false }))
    )
)

(define-public (claim-bounty (id uint))
    (let
        (
            (bounty (unwrap! (map-get? bounties id) (err u404)))
        )
        (ok (map-set bounties id (merge bounty { claimant: (some tx-sender) })))
    )
)

```
