---
title: "Trait proxy-1-1"
draft: true
---
```
;; Proxy for Target 1: SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.gl-api (sBTC/USDh)

(use-trait ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait oracle-trait 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.gl-oracle-trait-pyth.oracle-trait)

(define-constant TARGET 'SP1Y5YSTAHZ88XYK1VPDH24GY0HPX5J4JECTMY4A1.gl-api)

(define-public (open
    (base-token   <ft-trait>)
    (quote-token  <ft-trait>)
    (long         bool)
    (collateral   uint)
    (leverage     uint)
    (desired      uint)
    (slippage     uint)
    (ctx0         { identifier: (buff 32), message: (buff 8192), oracle: <oracle-trait> })
  )
  (contract-call? TARGET open base-token quote-token long collateral leverage desired slippage ctx0)
)

(define-public (close
    (base-token   <ft-trait>)
    (quote-token  <ft-trait>)
    (position-id  uint)
    (desired      uint)
    (slippage     uint)
    (ctx0         { identifier: (buff 32), message: (buff 8192), oracle: <oracle-trait> })
  )
  (contract-call? TARGET close base-token quote-token position-id desired slippage ctx0)
)

```
