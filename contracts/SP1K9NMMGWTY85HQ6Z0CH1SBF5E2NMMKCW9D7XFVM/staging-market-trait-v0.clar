(use-trait ft-trait .staging-ft-trait-v0.ft-trait)

(define-trait market-trait
  (
    (collateral-add (<ft-trait> uint (optional (list 3 (buff 8192)))) (response uint uint))
    
    (collateral-remove (<ft-trait> uint (optional principal) (optional (list 3 (buff 8192)))) (response uint uint))
    
    (borrow (<ft-trait> uint (optional principal) (optional (list 3 (buff 8192)))) (response bool uint))
    
    (repay (<ft-trait> uint (optional principal)) (response uint uint))
    
    (liquidate (principal <ft-trait> <ft-trait> uint uint (optional (list 3 (buff 8192)))) 
               (response { debt: uint, collateral: uint } uint))
    
    (liquidate-multi ((list 64 { borrower: principal,
                                  collateral-ft: <ft-trait>,
                                  debt-ft: <ft-trait>,
                                  debt-amount: uint,
                                  min-collateral-expected: uint }))
                     (response (list 64 (response { debt: uint, collateral: uint } uint)) uint))
    
  )
)
