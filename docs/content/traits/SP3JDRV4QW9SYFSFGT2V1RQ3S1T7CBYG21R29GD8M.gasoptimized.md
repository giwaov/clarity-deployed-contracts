---
title: "Trait gasoptimized"
draft: true
---
```
;; Gas-Optimized Storage Contract
;; Minimizes cost by using efficient data structures and operations

;; Use map instead of data-var for per-user storage (more efficient)
(define-map storage principal uint)

;; Single optimized write function
(define-public (store (val uint))
  (ok (map-set storage tx-sender val))
)

;; Read function - returns none if not found
(define-read-only (load (user principal))
  (map-get? storage user)
)

;; Batch write to save on multiple transactions
(define-public (store-batch (vals (list 10 uint)))
  (ok (map set-val vals))
)

;; Helper for batch operation
(define-private (set-val (val uint))
  (map-set storage tx-sender val)
)

;; Delete to free storage and get refund
(define-public (clear)
  (ok (map-delete storage tx-sender))
)
```
