---
title: "Trait wager"
draft: true
---
```
;; Contract: Betting Pool
;; Description: Users claim prize if they picked correctly.

(define-map user-pick principal (string-ascii 10))

(define-public (place-bet (team (string-ascii 10)))
    (ok (map-set user-pick tx-sender team))
)

(define-public (claim-prize)
    (let
        (
            (my-pick (unwrap! (map-get? user-pick tx-sender) (err u404)))
            (official-result (unwrap-panic (contract-call? .referee get-result)))
        )
        ;; Check if user picked the winner
        (asserts! (is-eq my-pick official-result) (err u400))
        
        ;; Simulate Payout (Logic simplified for demo)
        (ok "You Won! Prize Sent.")
    )
)
```
