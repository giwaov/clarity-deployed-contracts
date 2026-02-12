---
title: "Trait get-sbtc-balances-at-heights-v2"
draft: true
---
```
;; Get sBTC balances for multiple addresses at multiple block heights
;; Results are printed as events for each address/height combination

(define-data-var temp-height uint u0)
(define-data-var temp-addresses (list 5 principal) (list))

(define-read-only (get-sbtc-balance (address principal))
  (unwrap-panic (contract-call? 'SM3VDXK3WZZSA84XXFKAFAF15NNZX32CTSG82JFQ4.sbtc-token get-balance-available address))
)

(define-private (get-balance-at-height (address principal))
  (at-block
    (unwrap-panic (get-stacks-block-info? id-header-hash (var-get temp-height)))
    (print {
      address: address,
      height: (var-get temp-height),
      balance: (get-sbtc-balance address)
    })
  )
)

(define-private (process-height (height uint))
  (begin
    (var-set temp-height height)
    (map get-balance-at-height (var-get temp-addresses))
  )
)

(define-public (get-balances-at-heights
    (addresses (list 5 principal))
    (heights (list 100 uint))
  )
  (begin
    (var-set temp-addresses addresses)
    (map process-height heights)
    (ok true)
  )
)

```
