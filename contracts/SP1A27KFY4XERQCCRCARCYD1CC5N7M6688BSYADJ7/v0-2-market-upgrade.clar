(impl-trait .dao-traits.proposal-script)

(define-constant CAP-USDH-SUPPLY u1800000000000000)

(define-public (execute)
  (begin
    (try! (contract-call? .v0-market-vault set-impl .v0-2-market))

    (try! (contract-call? .v0-vault-stx set-authorized-contract .v0-2-market true))
    (try! (contract-call? .v0-vault-sbtc set-authorized-contract .v0-2-market true))
    (try! (contract-call? .v0-vault-ststx set-authorized-contract .v0-2-market true))
    (try! (contract-call? .v0-vault-usdc set-authorized-contract .v0-2-market true))
    (try! (contract-call? .v0-vault-usdh set-authorized-contract .v0-2-market true))
    (try! (contract-call? .v0-vault-ststxbtc set-authorized-contract .v0-2-market true))

    (try! (contract-call? .v0-vault-stx set-authorized-contract .v0-1-market false))
    (try! (contract-call? .v0-vault-sbtc set-authorized-contract .v0-1-market false))
    (try! (contract-call? .v0-vault-ststx set-authorized-contract .v0-1-market false))
    (try! (contract-call? .v0-vault-usdc set-authorized-contract .v0-1-market false))
    (try! (contract-call? .v0-vault-usdh set-authorized-contract .v0-1-market false))
    (try! (contract-call? .v0-vault-ststxbtc set-authorized-contract .v0-1-market false))

    (try! (contract-call? .v0-vault-usdh set-cap-supply CAP-USDH-SUPPLY))
    
    (ok true)))
