;; Deposit Pool Trait
;; Defines the interface for deposit pool contracts

(define-trait deposit-pool-trait
    (
        ;; Deposit STX into the pool
        (deposit (uint) (response bool uint))
        
        ;; Withdraw STX from the pool
        (withdraw (uint) (response bool uint))
        
        ;; Get deposit information for a user
        (get-deposit (principal) (response (optional {amount: uint, timestamp: uint, active: bool}) uint))
        
        ;; Get total pool amount
        (get-total-pool () (response uint uint))
    )
)
