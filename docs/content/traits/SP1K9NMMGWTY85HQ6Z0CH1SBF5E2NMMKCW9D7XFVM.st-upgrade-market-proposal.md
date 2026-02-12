---
title: "Trait st-upgrade-market-proposal"
draft: true
---
```
;; Proposal to authorize market contract in market-vault
;; Sets market as the implementation contract for market-vault

(impl-trait .st-dao-traits.proposal-script)

(define-public (execute)
  (begin
    ;; Set market as implementation in market-vault
    (try! (contract-call? .st-market-vault set-impl .st-1-market))

    ;; =========================================================================
    ;; STEP 2: AUTHORIZE MARKET CONTRACT
    ;; Allows market to call deposit, redeem, borrow, repay on vaults
    ;; =========================================================================
    
    (try! (contract-call? .st-vault-stx set-authorized-contract .st-1-market true))
    (try! (contract-call? .st-vault-sbtc set-authorized-contract .st-1-market true))
    (try! (contract-call? .st-vault-ststx set-authorized-contract .st-1-market true))
    (try! (contract-call? .st-vault-usdc set-authorized-contract .st-1-market true))
    (try! (contract-call? .st-vault-usdh set-authorized-contract .st-1-market true))
    ;; latest vault
    (try! (contract-call? .st-vault-ststxbtc set-authorized-contract .st-1-market true))

    (try! (contract-call? .st-vault-stx set-authorized-contract .st-market false))
    (try! (contract-call? .st-vault-sbtc set-authorized-contract .st-market false))
    (try! (contract-call? .st-vault-ststx set-authorized-contract .st-market false))
    (try! (contract-call? .st-vault-usdc set-authorized-contract .st-market false))
    (try! (contract-call? .st-vault-usdh set-authorized-contract .st-market false))
    
    (ok true)))

```
