(impl-trait .dao-traits.proposal-script)

(define-public (execute)
  (begin
    (try! (contract-call? .market-vault set-impl .v0-0-market))

    (try! (contract-call? .vault-stx set-authorized-contract .v0-0-market true))
    (try! (contract-call? .vault-sbtc set-authorized-contract .v0-0-market true))
    (try! (contract-call? .vault-ststx set-authorized-contract .v0-0-market true))
    (try! (contract-call? .vault-usdc set-authorized-contract .v0-0-market true))
    (try! (contract-call? .vault-usdh set-authorized-contract .v0-0-market true))
    (try! (contract-call? .vault-ststxbtc set-authorized-contract .v0-0-market true))

    (try! (contract-call? .vault-stx set-authorized-contract .market false))
    (try! (contract-call? .vault-sbtc set-authorized-contract .market false))
    (try! (contract-call? .vault-ststx set-authorized-contract .market false))
    (try! (contract-call? .vault-usdc set-authorized-contract .market false))
    (try! (contract-call? .vault-usdh set-authorized-contract .market false))
    (try! (contract-call? .vault-ststxbtc set-authorized-contract .market false))
    
    (ok true)))
