;; ---------------------------------------------------------
;; Protocol Fees
;; Fixed STX protocol fee
;; ---------------------------------------------------------

;; Admin is the deployer of the contract
(define-constant ADMIN tx-sender)
(define-constant FEE u1000)


(define-public (pay-fee)
    (begin
        (try! (stx-transfer? FEE tx-sender (as-contract tx-sender)))
        (ok FEE)
    )
)

(define-public (withdraw-fees)
  (begin
    ;; Ensure only admin can withdraw
    (asserts! (is-eq tx-sender ADMIN) (err u401))

    ;; Get full contract balance
    (let ((balance (stx-get-balance (as-contract tx-sender))))
      ;; Transfer entire balance to admin
      (as-contract
        (try! (stx-transfer? balance tx-sender ADMIN))
      )
      (ok balance)
    )
  )
)
