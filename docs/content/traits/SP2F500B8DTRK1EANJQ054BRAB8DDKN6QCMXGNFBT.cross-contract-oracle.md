---
title: "Trait cross-contract-oracle"
draft: true
---
```
;; Cross-Contract Oracle
;; Aggregates data from multiple sources for accurate price feeds

(define-constant contract-owner tx-sender)
(define-constant err-not-oracle (err u1000))
(define-constant err-stale-data (err u1001))
(define-constant err-insufficient-reports (err u1002))

(define-constant max-data-age u144) ;; ~1 day in blocks

(define-map oracles
    principal
    bool
)

(define-map price-feeds
    { asset: (string-ascii 10) }
    {
        price: uint,
        last-updated: uint,
        report-count: uint
    }
)

(define-map oracle-reports
    { asset: (string-ascii 10), oracle: principal }
    {
        price: uint,
        timestamp: uint
    }
)

;; Initialize contract owner as oracle
(map-set oracles contract-owner true)

;; Add oracle
(define-public (add-oracle (new-oracle principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-oracle)
        (map-set oracles new-oracle true)
        (ok true)
    )
)

;; Submit price report
(define-public (submit-price (asset (string-ascii 10)) (price uint))
    (begin
        (asserts! (is-oracle tx-sender) err-not-oracle)
        
        ;; Record oracle report
        (map-set oracle-reports
            { asset: asset, oracle: tx-sender }
            {
                price: price,
                timestamp: stacks-block-height
            }
        )
        
        ;; Update aggregated price feed
        (let
            (
                (current-feed (default-to
                    { price: u0, last-updated: u0, report-count: u0 }
                    (map-get? price-feeds { asset: asset })
                ))
            )
            (map-set price-feeds
                { asset: asset }
                {
                    price: price, ;; Simplified: using latest price; production would aggregate
                    last-updated: stacks-block-height,
                    report-count: (+ (get report-count current-feed) u1)
                }
            )
        )
        
        (ok true)
    )
)

;; Get price with freshness check
(define-public (get-price (asset (string-ascii 10)))
    (let
        (
            (feed (unwrap! (map-get? price-feeds { asset: asset }) err-insufficient-reports))
        )
        (asserts! (<= (- stacks-block-height (get last-updated feed)) max-data-age) err-stale-data)
        (ok (get price feed))
    )
)

;; Helper functions
(define-private (is-oracle (user principal))
    (default-to false (map-get? oracles user))
)

;; Read-only functions
(define-read-only (get-latest-price (asset (string-ascii 10)))
    (map-get? price-feeds { asset: asset })
)

(define-read-only (get-oracle-report (asset (string-ascii 10)) (oracle principal))
    (map-get? oracle-reports { asset: asset, oracle: oracle })
)

(define-read-only (is-data-fresh (asset (string-ascii 10)))
    (match (map-get? price-feeds { asset: asset })
        feed (ok (<= (- stacks-block-height (get last-updated feed)) max-data-age))
        (ok false)
    )
)

```
