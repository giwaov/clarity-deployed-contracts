---
title: "Trait agp627"
draft: true
---
```
;; SPDX-License-Identifier: BUSL-1.1

(impl-trait 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.proposal-trait.proposal-trait)

(define-public (execute (sender principal))
  (let (
    ;; Get ALEX balance from treasury-grant-v3
    (v3-balance (unwrap-panic (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex get-balance-fixed 'SP1E0XBN9T4B10E9QMR7XMFJPMA19D77WY3KP2QKC.treasury-grant-v3))))
    
    ;; Burn ALEX from treasury-grant-v3
    (and (> v3-balance u0)
      (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex burn-fixed v3-balance 'SP1E0XBN9T4B10E9QMR7XMFJPMA19D77WY3KP2QKC.treasury-grant-v3)))
    
    ;; Mint the same amount to treasury-grant
    (and (> v3-balance u0)
      (try! (contract-call? 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.token-alex mint-fixed v3-balance 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.treasury-grant)))
    
    (print { 
      notification: "agp627-executed",
      v3-balance: v3-balance,
      burned-from: 'SP1E0XBN9T4B10E9QMR7XMFJPMA19D77WY3KP2QKC.treasury-grant-v3,
      minted-to: 'SP102V8P0F7JX67ARQ77WEA3D3CFB5XW39REDT0AM.treasury-grant
    })
    
    (ok true)
  )
)


```
