---
title: "Trait proposal-flwl"
draft: true
---
```

(impl-trait 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-dao-traits.proposal-script)

;; Zest vault contracts
(define-constant VAULT_SBTC 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-sbtc)
(define-constant VAULT_STX 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-stx)
(define-constant VAULT_USDH 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-usdh)

(define-public (execute)
  (begin

    (try! (contract-call? VAULT_SBTC set-flashloan-permissions
      'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM
      true   
      true
    ))

    (try! (contract-call? VAULT_STX set-flashloan-permissions
      'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM
      true
      true
    ))

    (try! (contract-call? VAULT_USDH set-flashloan-permissions
      'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM
      true
      true
    ))

    (try! (contract-call? VAULT_SBTC set-flashloan-permissions
      'SP193AZ8C38VPX29YZTP3HQ403083BQETP3CJD9P8
      true   
      true
    ))

    (try! (contract-call? VAULT_STX set-flashloan-permissions
      'SP193AZ8C38VPX29YZTP3HQ403083BQETP3CJD9P8
      true
      true
    ))

    (try! (contract-call? VAULT_USDH set-flashloan-permissions
      'SP193AZ8C38VPX29YZTP3HQ403083BQETP3CJD9P8
      true
      true
    ))

    (ok true)))

```
