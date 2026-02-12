;; Simple Token V4
(define-fungible-token simple-token-4)

(define-public (mint (amount uint))
  (ft-mint? simple-token-4 amount tx-sender))

(define-public (transfer (amount uint) (recipient principal))
  (ft-transfer? simple-token-4 amount tx-sender recipient))

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance simple-token-4 account)))