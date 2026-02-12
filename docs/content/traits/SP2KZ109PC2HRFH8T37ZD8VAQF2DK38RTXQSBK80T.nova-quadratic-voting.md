---
title: "Trait nova-quadratic-voting"
draft: true
---
```

;; nova-quadratic-voting.clar
;; Voting power = sqrt(tokens)
;; CLARITY VERSION: 2

(define-map votes
    {proposal: uint, voter: principal}
    uint
)

(define-public (vote (proposal uint) (amount uint))
    (let (
        (cost (* amount amount)) ;; simplified cost model (credits)
    )
    ;; User pays 'cost' in credits (omitted for brevity)
    (map-set votes {proposal: proposal, voter: tx-sender} amount)
    (ok true))
)

(define-read-only (get-voting-power (proposal uint) (voter principal))
    (default-to u0 (map-get? votes {proposal: proposal, voter: voter}))
)

```
