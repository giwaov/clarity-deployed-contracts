---
title: "Trait hurt-salmon-asp"
draft: true
---
```
;; Experimental

(use-trait ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)

(use-trait oracle-trait 'SP3YBY0BH4ANC0Q35QB6PD163F943FVFVDFM1SH7S.gl-oracle-trait-pyth.oracle-trait)

(define-constant VELAR_GL_API 'SP3YBY0BH4ANC0Q35QB6PD163F943FVFVDFM1SH7S.gl-api)

;; Compatibility: same signature as Velar `gl-api.open`
(define-public (open
    (base-token <ft-trait>)
    (quote-token <ft-trait>)
    (long bool)
    (collateral uint)
    (leverage uint)
    (desired uint)
    (slippage uint)
    (ctx0 {
      identifier: (buff 32),
      message: (buff 8192),
      oracle: <oracle-trait>,
    })
  )
  (contract-call? VELAR_GL_API open base-token quote-token long collateral
    leverage desired slippage ctx0
  )
)

;; Compatibility: same signature as Velar `gl-api.close`
(define-public (close
    (base-token <ft-trait>)
    (quote-token <ft-trait>)
    (position-id uint)
    (desired uint)
    (slippage uint)
    (ctx0 {
      identifier: (buff 32),
      message: (buff 8192),
      oracle: <oracle-trait>,
    })
  )
  (contract-call? VELAR_GL_API close base-token quote-token position-id desired
    slippage ctx0
  )
)

;; Convenience wrappers (long/short fixed)
(define-public (open-long
    (base-token <ft-trait>)
    (quote-token <ft-trait>)
    (collateral uint)
    (leverage uint)
    (desired uint)
    (slippage uint)
    (ctx0 {
      identifier: (buff 32),
      message: (buff 8192),
      oracle: <oracle-trait>,
    })
  )
  (contract-call? VELAR_GL_API open base-token quote-token true collateral
    leverage desired slippage ctx0
  )
)

(define-public (open-short
    (base-token <ft-trait>)
    (quote-token <ft-trait>)
    (collateral uint)
    (leverage uint)
    (desired uint)
    (slippage uint)
    (ctx0 {
      identifier: (buff 32),
      message: (buff 8192),
      oracle: <oracle-trait>,
    })
  )
  (contract-call? VELAR_GL_API open base-token quote-token false collateral
    leverage desired slippage ctx0
  )
)

```
