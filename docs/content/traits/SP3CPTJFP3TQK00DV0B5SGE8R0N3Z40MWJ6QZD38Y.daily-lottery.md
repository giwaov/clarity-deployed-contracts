---
title: "Trait daily-lottery"
draft: true
---
```
;; daily-lottery.clar
;; Cycle-based lottery (conceptually daily)

(define-map tickets { round: uint, user: principal } bool)
(define-data-var current-round uint u1)
(define-data-var round-end-time uint u0)
(define-constant ROUND_DURATION u144) ;; ~24 hours in blocks
(define-constant TICKET_PRICE u100)

(define-public (buy-ticket)
    (let
        (
            (time block-height)
            (round (var-get current-round))
        )
        ;; Check if round ended
        (if (> time (var-get round-end-time))
            (begin
                 (var-set current-round (+ round u1))
                 (var-set round-end-time (+ time ROUND_DURATION))
            )
            false
        )
        
        (try! (stx-transfer? TICKET_PRICE tx-sender (as-contract tx-sender)))
        (map-set tickets { round: (var-get current-round), user: tx-sender } true)
        (ok true)
    )
)

```
