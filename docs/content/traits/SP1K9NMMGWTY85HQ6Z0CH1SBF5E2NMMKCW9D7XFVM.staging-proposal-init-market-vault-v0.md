---
title: "Trait staging-proposal-init-market-vault-v0"
draft: true
---
```
;; Proposal to authorize market contract in market-vault
;; Sets market as the implementation contract for market-vault

(impl-trait .staging-dao-traits-v0.proposal-script)

(define-public (execute)
  (begin
    ;; Set market as implementation in market-vault
    (try! (contract-call? .staging-market-vault-v0 set-impl .staging-market-v0))
    
    (ok true)))

```
