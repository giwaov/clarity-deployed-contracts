;; Simple Token V9
(define-fungible-token simple-token-9)

(define-public (mint (amount uint))
  (ft-mint? simple-token-9 amount tx-sender))

(define-public (transfer (amount uint) (recipient principal))
  (ft-transfer? simple-token-9 amount tx-sender recipient))

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance simple-token-9 account)))