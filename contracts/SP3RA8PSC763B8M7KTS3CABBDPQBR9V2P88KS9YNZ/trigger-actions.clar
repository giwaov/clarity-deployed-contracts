;; ============================================
;; TRIGGER ACTIONS - Execution Logic
;; Clarity 4 Smart Contract
;; ============================================

(define-data-var processing-user principal tx-sender)
(define-data-var processing-balance uint u0)

(define-public (execute-trigger (user principal))
  (begin
    (asserts! (is-some (contract-call? .heartbeat-core get-status user)) (err u404))
    ;; 1. Attempt to trigger the switch (will fail if already triggered or not time)
    (try! (contract-call? .heartbeat-core try-trigger user))
    
    ;; 2. Get available balance and beneficiaries
    (let
      (
        (balance (contract-call? .vault get-balance user))
        (beneficiaries (contract-call? .beneficiary-mgr get-beneficiaries user))
      )
      ;; 3. Setup context for distribution
      (var-set processing-user user)
      (var-set processing-balance balance)
      
      ;; 4. Distribute funds
      (map distribute-one beneficiaries)
      
      (ok true)
    )
  )
)

(define-private (distribute-one (item { recipient: principal, percentage: uint }))
  (let
    (
      (amount (/ (* (var-get processing-balance) (get percentage item)) u100))
    )
    (if (> amount u0)
      (unwrap-panic (contract-call? .vault distribute-stx (var-get processing-user) (get recipient item) amount))
      true
    )
  )
)
