;; Contract: My Custom Token
;; Description: A simple fungible token implementation.

(define-fungible-token builder-coin)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u200))

(define-public (mint (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ft-mint? builder-coin amount recipient)
    )
)

(define-public (transfer (amount uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-owner-only)
        (ft-transfer? builder-coin amount sender recipient)
    )
)

(define-read-only (get-balance (account principal))
    (ok (ft-get-balance builder-coin account))
)