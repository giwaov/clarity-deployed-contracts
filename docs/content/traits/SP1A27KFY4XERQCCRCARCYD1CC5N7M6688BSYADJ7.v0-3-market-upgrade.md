---
title: "Trait v0-3-market-upgrade"
draft: true
---
```
(impl-trait .dao-traits.proposal-script)

(define-constant UTIL-POINTS-USDH (list u0 u2000 u4000 u6000 u8000 u8500 u9250 u10000))
(define-constant RATE-POINTS-USDH (list u0 u141 u282 u424 u565 u600 u4950 u9300))

(define-public (execute)
  (begin
    (try! (contract-call? .v0-market-vault set-impl .v0-3-market))

    (try! (contract-call? .v0-vault-stx set-authorized-contract .v0-3-market true))
    (try! (contract-call? .v0-vault-sbtc set-authorized-contract .v0-3-market true))
    (try! (contract-call? .v0-vault-ststx set-authorized-contract .v0-3-market true))
    (try! (contract-call? .v0-vault-usdc set-authorized-contract .v0-3-market true))
    (try! (contract-call? .v0-vault-usdh set-authorized-contract .v0-3-market true))
    (try! (contract-call? .v0-vault-ststxbtc set-authorized-contract .v0-3-market true))

    (try! (contract-call? .v0-vault-stx set-authorized-contract .v0-2-market false))
    (try! (contract-call? .v0-vault-sbtc set-authorized-contract .v0-2-market false))
    (try! (contract-call? .v0-vault-ststx set-authorized-contract .v0-2-market false))
    (try! (contract-call? .v0-vault-usdc set-authorized-contract .v0-2-market false))
    (try! (contract-call? .v0-vault-usdh set-authorized-contract .v0-2-market false))
    (try! (contract-call? .v0-vault-ststxbtc set-authorized-contract .v0-2-market false))

    (try! (contract-call? .v0-vault-usdh set-points-util UTIL-POINTS-USDH))
    (try! (contract-call? .v0-vault-usdh set-points-rate RATE-POINTS-USDH))
    
    (ok true)))

```
