---
title: "Trait staging-proposal-set-rates-v0"
draft: true
---
```
(impl-trait .staging-dao-traits-v0.proposal-script)

(define-constant UTIL-POINTS (list u0 u2500 u5000 u7000 u7500 u8500 u9000 u10000))
(define-constant RATE-POINTS (list u200 u250 u400 u600 u800 u1800 u2500 u10000))
(define-constant RESERVE-FACTOR u1000) ;; 10% to DAO treasury

(define-public (execute)
  (begin
    (try! (contract-call? .staging-vault-stx-v0 set-points-util UTIL-POINTS))
    (try! (contract-call? .staging-vault-stx-v0 set-points-rate RATE-POINTS))
    (try! (contract-call? .staging-vault-stx-v0 set-fee-reserve RESERVE-FACTOR))
    

    (try! (contract-call? .staging-vault-sbtc-v0 set-points-util UTIL-POINTS))
    (try! (contract-call? .staging-vault-sbtc-v0 set-points-rate RATE-POINTS))
    (try! (contract-call? .staging-vault-sbtc-v0 set-fee-reserve RESERVE-FACTOR))
    
    (try! (contract-call? .staging-vault-ststx-v0 set-points-util UTIL-POINTS))
    (try! (contract-call? .staging-vault-ststx-v0 set-points-rate RATE-POINTS))
    (try! (contract-call? .staging-vault-ststx-v0 set-fee-reserve RESERVE-FACTOR))

    (try! (contract-call? .staging-vault-usdc-v0 set-points-util UTIL-POINTS))
    (try! (contract-call? .staging-vault-usdc-v0 set-points-rate RATE-POINTS))
    (try! (contract-call? .staging-vault-usdc-v0 set-fee-reserve RESERVE-FACTOR))
    
    (try! (contract-call? .staging-vault-usdh-v0 set-points-util UTIL-POINTS))
    (try! (contract-call? .staging-vault-usdh-v0 set-points-rate RATE-POINTS))
    (try! (contract-call? .staging-vault-usdh-v0 set-fee-reserve RESERVE-FACTOR))
    
    (ok true)))

```
