
(impl-trait 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-dao-traits.proposal-script)

(define-public (execute)
  (begin

    (try! (contract-call? 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-sbtc set-flashloan-permissions
      'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM
      true   
      true
    ))

    (try! (contract-call? 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-stx set-flashloan-permissions
      'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM
      true
      true
    ))

    (try! (contract-call? 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-usdh set-flashloan-permissions
      'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM
      true
      true
    ))

    (try! (contract-call? 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-sbtc set-flashloan-permissions
      'SP193AZ8C38VPX29YZTP3HQ403083BQETP3CJD9P8
      true   
      true
    ))

    (try! (contract-call? 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-stx set-flashloan-permissions
      'SP193AZ8C38VPX29YZTP3HQ403083BQETP3CJD9P8
      true
      true
    ))

    (try! (contract-call? 'SP1K9NMMGWTY85HQ6Z0CH1SBF5E2NMMKCW9D7XFVM.sm-vault-usdh set-flashloan-permissions
      'SP193AZ8C38VPX29YZTP3HQ403083BQETP3CJD9P8
      true
      true
    ))

    (ok true)))
