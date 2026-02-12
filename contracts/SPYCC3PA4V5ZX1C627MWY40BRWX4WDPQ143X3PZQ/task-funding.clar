;; ---------------------------------------------------------
;; Task Funding
;; Funds tasks with STX
;; ---------------------------------------------------------

(define-public (fund-task (amount uint))
    (begin
        ;; Transfers STX from user to contract
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (ok amount)
    )
)
