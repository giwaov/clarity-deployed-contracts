---
title: "Trait position-zest-v4"
draft: true
---
```
;; @contract Supported Position - Zest
;; @version 3

;; (impl-trait .position-trait-v1.position-trait)

(define-read-only (get-holder-balance (user principal))
  (contract-call? 'SP1A27KFY4XERQCCRCARCYD1CC5N7M6688BSYADJ7.vault-ststxbtc get-balance user)
)
```
