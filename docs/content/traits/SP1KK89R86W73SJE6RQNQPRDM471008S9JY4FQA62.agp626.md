---
title: "Trait agp626"
draft: true
---
```
;; SPDX-License-Identifier: BUSL-1.1

(impl-trait 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.proposal-trait.proposal-trait)

(define-public (execute (sender principal))
  (let (
    ;; Get ALEX balance from legacy executor-dao
    (legacy-balance (unwrap-panic (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex get-balance-fixed 'SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.executor-dao))))
    
    ;; Burn ALEX from legacy executor-dao
    (if (> legacy-balance u0)
      (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex burn-fixed legacy-balance 'SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.executor-dao))
      true)
    
    ;; Mint the same amount to treasury-grant-v3
    (if (> legacy-balance u0)
      (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex mint-fixed legacy-balance 'SP1E0XBN9T4B10E9QMR7XMFJPMA19D77WY3KP2QKC.treasury-grant-v3))
      true)
    
    (print { 
      notification: "agp626-executed",
      legacy-balance: legacy-balance,
      burned-from: 'SP3K8BC0PPEVCV7NZ6QSRWPQ2JE9E5B6N3PA0KBR9.executor-dao,
      minted-to: 'SP1E0XBN9T4B10E9QMR7XMFJPMA19D77WY3KP2QKC.treasury-grant-v3
    })
    
    (ok true)
  )
)


```
