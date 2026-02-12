---
title: "Trait oracle-price-feed"
draft: true
---
```
;; Oracle Price Feed - Clarity 4
;; Decentralized price oracle with multi-reporter aggregation

(define-constant contract-owner tx-sender)
(define-constant err-unauthorized (err u5000))
(define-constant err-stale-price (err u5001))

(define-data-var price-stx-usd uint u0)
(define-data-var last-update uint u0)
(define-data-var max-age uint u144) ;; ~1 day

(define-map authorized-reporters principal bool)
(define-map price-reports {reporter: principal, round: uint} 
    {price: uint, timestamp: uint}
)
(define-map round-submissions uint (list 10 uint))
(define-data-var current-round uint u0)

(define-read-only (get-price)
    (let (
        (age (- stacks-block-height (var-get last-update)))
    )
        (if (<= age (var-get max-age))
            (ok (var-get price-stx-usd))
            err-stale-price
        )
    )
)

(define-read-only (is-reporter (reporter principal))
    (default-to false (map-get? authorized-reporters reporter))
)

(define-public (report-price (price uint))
    (let (
        (round (var-get current-round))
    )
        (asserts! (is-reporter tx-sender) err-unauthorized)
        
        (map-set price-reports {reporter: tx-sender, round: round}
            {price: price, timestamp: stacks-block-height}
        )
        (ok true)
    )
)

(define-public (aggregate-prices)
    (let (
        (round (var-get current-round))
        ;; In production, collect prices and calculate median
        (median-price u30000000) ;; Placeholder
    )
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        
        (var-set price-stx-usd median-price)
        (var-set last-update stacks-block-height)
        (var-set current-round (+ round u1))
        (ok median-price)
    )
)

(define-public (add-reporter (reporter principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        (ok (map-set authorized-reporters reporter true))
    )
)

(define-public (remove-reporter (reporter principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-unauthorized)
        (ok (map-set authorized-reporters reporter false))
    )
)

;; Initialize
(begin
    (map-set authorized-reporters contract-owner true)
)

```
