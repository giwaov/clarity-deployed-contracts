;; fungible-token.clar

(define-fungible-token example-token)

(define-constant CONTRACT-OWNER tx-sender)
(define-constant TOTAL-SUPPLY u1000000)

(begin
  (ft-mint? example-token TOTAL-SUPPLY CONTRACT-OWNER)
)

(define-public (transfer (amount uint) (recipient principal))
  (ft-transfer? example-token amount tx-sender recipient)
)

(define-read-only (get-balance (account principal))
  (ft-get-balance example-token account)
)

(define-read-only (get-supply)
  (ft-get-supply example-token)
)
