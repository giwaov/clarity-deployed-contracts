---
title: "Trait lottery"
draft: true
---
```
;; Contract: Simple Lottery
;; Description: Buy tickets and wait for the draw.

(define-map tickets uint principal)
(define-data-var ticket-count uint u0)
(define-constant ticket-price u10) ;; Price is 10 micro-STX
(define-constant admin tx-sender)

(define-public (buy-ticket)
    (let
        (
            (new-id (+ (var-get ticket-count) u1))
        )
        ;; Pay for ticket
        (try! (stx-transfer? ticket-price tx-sender (as-contract tx-sender)))
        
        ;; Register ticket
        (map-set tickets new-id tx-sender)
        (var-set ticket-count new-id)
        (ok new-id)
    )
)

(define-public (pay-winner (winning-id uint))
    (let
        (
            (winner (unwrap! (map-get? tickets winning-id) (err u404)))
            (jackpot (stx-get-balance (as-contract tx-sender)))
        )
        (asserts! (is-eq tx-sender admin) (err u403))
        (as-contract (stx-transfer? jackpot tx-sender winner))
    )
)
```
