---
title: "Trait rusdh5"
draft: true
---
```
(impl-trait .dao-traits.proposal-script)

(define-constant UTIL-POINTS-USDH (list u0 u2000 u4000 u6000 u8000 u8500 u9250 u10000))
(define-constant RATE-POINTS-USDH (list u0 u118 u235 u353 u471 u500 u4850 u9200))

(define-public (execute)
  (begin

    (try! (contract-call? .v0-vault-usdh set-points-util UTIL-POINTS-USDH))
    (try! (contract-call? .v0-vault-usdh set-points-rate RATE-POINTS-USDH))
    
    (ok true)))

```
