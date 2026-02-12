;; Loan Tracker
(define-map loans {loan-id: uint} {borrower: principal, lender: principal, principal-amount: uint, interest-rate: uint, status: (string-ascii 20)})
(define-public (create-loan (loan-id uint) (lender principal) (principal-amount uint) (interest-rate uint) (status (string-ascii 20)))
  (begin (map-set loans {loan-id: loan-id} {borrower: tx-sender, lender: lender, principal-amount: principal-amount, interest-rate: interest-rate, status: status}) (ok true)))
(define-read-only (get-loan (loan-id uint))
  (map-get? loans {loan-id: loan-id}))
