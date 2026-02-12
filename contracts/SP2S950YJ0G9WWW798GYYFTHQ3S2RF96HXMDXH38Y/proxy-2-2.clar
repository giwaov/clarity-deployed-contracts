;; Proxy for Target 2: SP3CSZFP219B4GD3HM8R8RSWYAS05K7RCTMKTRNRC.gl-api (sBTC/aeUSDC)

(use-trait ft-trait 'SP2AKWJYC7BNY18W1XXKPGP0YVEK63QJG4793Z2D4.sip-010-trait-ft-standard.sip-010-trait)
(use-trait oracle-trait 'SP3CSZFP219B4GD3HM8R8RSWYAS05K7RCTMKTRNRC.gl-oracle-trait-pyth.oracle-trait)

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
  ;; NOTE: `contract-call?` requires a literal contract identifier (not a constant principal),
  ;; otherwise it aborts with `ContractCallExpectName` on mainnet (epoch33).
  (contract-call? 'SP3CSZFP219B4GD3HM8R8RSWYAS05K7RCTMKTRNRC.gl-api open base-token quote-token long collateral leverage desired slippage ctx0)
)

(define-public (close
    (base-token   <ft-trait>)
    (quote-token  <ft-trait>)
    (position-id  uint)
    (desired      uint)
    (slippage     uint)
    (ctx0         { identifier: (buff 32), message: (buff 8192), oracle: <oracle-trait> })
  )
  (contract-call? 'SP3CSZFP219B4GD3HM8R8RSWYAS05K7RCTMKTRNRC.gl-api close base-token quote-token position-id desired slippage ctx0)
)
