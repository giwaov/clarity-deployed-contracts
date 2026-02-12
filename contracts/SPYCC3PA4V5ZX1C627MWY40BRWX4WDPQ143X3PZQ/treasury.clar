;; ---------------------------------------------------------
;; Treasury
;; Displays contract STX balance
;; ---------------------------------------------------------

(define-read-only (balance)
    (stx-get-balance (as-contract tx-sender))
)