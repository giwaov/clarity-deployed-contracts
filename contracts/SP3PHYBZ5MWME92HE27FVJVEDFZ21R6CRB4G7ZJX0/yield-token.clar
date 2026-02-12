;; Contract: Yield Token
;; Description: A token minted only by the staking pool.

(define-fungible-token yield)
(define-constant contract-owner tx-sender)

;; Only the staking contract (or owner) can mint
(define-public (mint-reward (amount uint) (recipient principal))
    (begin
        (ft-mint? yield amount recipient)
    )
)

(define-read-only (get-balance (user principal))
    (ok (ft-get-balance yield user))
)