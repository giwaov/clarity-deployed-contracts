---
title: "Trait stacking-v1-0"
draft: true
---
```
;; stacking-v1-0
;; summary: Helper contract for calculating protocol collateral balances for vault owners

(define-read-only (get-user-sbtc-equivalent-balance (user principal))
    (let
        (
            (user-vaults (unwrap! (unwrap! (contract-call? .registry-v1-0 get-vaults-by-principal user) u0) u0))
        )
        (unwrap! (fold calculate-user-sbtc-equivalent-balance user-vaults (ok u0)) u0)
    )
)   

(define-private (calculate-user-sbtc-equivalent-balance (vault-id uint) (sbtc-response (response uint uint)))
    (match sbtc-response
        aggregate-sbtc
            (let
                (
                    (vault-info (unwrap-panic (contract-call? .registry-v1-0 get-vault-compounded-info vault-id u1)))
                    (vault-total-sbtc (get vault-total-collateral vault-info))             
                )
                (ok (+ aggregate-sbtc vault-total-sbtc))
            )
        err-resp
        (ok u0)
    )
)
```
