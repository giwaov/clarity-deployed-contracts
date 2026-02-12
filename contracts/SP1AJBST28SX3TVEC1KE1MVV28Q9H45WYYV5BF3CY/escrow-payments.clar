;; Escrow Payments
(define-map escrows {escrow-id: uint} {payer: principal, payee: principal, amount: uint, status: (string-ascii 20)})
(define-public (create-escrow (escrow-id uint) (payee principal) (amount uint) (status (string-ascii 20)))
  (begin (map-set escrows {escrow-id: escrow-id} {payer: tx-sender, payee: payee, amount: amount, status: status}) (ok true)))
(define-read-only (get-escrow (escrow-id uint))
  (map-get? escrows {escrow-id: escrow-id}))
