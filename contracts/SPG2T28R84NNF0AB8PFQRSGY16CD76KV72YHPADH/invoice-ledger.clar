;; Invoice Ledger
(define-map invoices {invoice-id: uint} {issuer: principal, recipient: principal, amount: uint, due-date: uint, paid: bool})
(define-public (create-invoice (invoice-id uint) (recipient principal) (amount uint) (due-date uint) (paid bool))
  (begin (map-set invoices {invoice-id: invoice-id} {issuer: tx-sender, recipient: recipient, amount: amount, due-date: due-date, paid: paid}) (ok true)))
(define-read-only (get-invoice (invoice-id uint))
  (map-get? invoices {invoice-id: invoice-id}))
