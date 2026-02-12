
(impl-trait 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-dao-traits.proposal-script)

(define-public (execute)
  (begin
    (try! (contract-call? 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-stx set-token-uri (some u"https://token-meta.s3.eu-central-1.amazonaws.com/zwSTX.json")))
    (ok true)))
