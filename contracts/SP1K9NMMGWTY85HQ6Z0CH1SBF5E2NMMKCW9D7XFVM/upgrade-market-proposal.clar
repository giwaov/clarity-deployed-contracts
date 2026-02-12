;; Proposal to authorize market contract in market-vault
;; Sets market as the implementation contract for market-vault

(impl-trait .staging-dao-traits-v0.proposal-script)

(define-public (execute)
  (begin
    ;; Set market as implementation in market-vault
    (try! (contract-call? .staging-market-vault-v0 set-impl .staging-market-v1))

    ;; =========================================================================
    ;; STEP 2: AUTHORIZE MARKET CONTRACT
    ;; Allows market to call deposit, redeem, borrow, repay on vaults
    ;; =========================================================================
    
    (try! (contract-call? .staging-vault-stx-v0 set-authorized-contract .staging-market-v1 true))
    (try! (contract-call? .staging-vault-sbtc-v0 set-authorized-contract .staging-market-v1 true))
    (try! (contract-call? .staging-vault-ststx-v0 set-authorized-contract .staging-market-v1 true))
    (try! (contract-call? .staging-vault-usdc-v0 set-authorized-contract .staging-market-v1 true))
    (try! (contract-call? .staging-vault-usdh-v0 set-authorized-contract .staging-market-v1 true))
    
    (ok true)))
