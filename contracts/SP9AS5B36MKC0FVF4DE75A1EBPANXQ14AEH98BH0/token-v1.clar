;; Simple Token V1
(define-fungible-token simple-token-1)

(define-public (mint (amount uint))
  (ft-mint? simple-token-1 amount tx-sender))

(define-public (transfer (amount uint) (recipient principal))
  (ft-transfer? simple-token-1 amount tx-sender recipient))

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance simple-token-1 account)))