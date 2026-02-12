;; Contract: Loyalty Points
;; Description: Fungible token for rewards.

(define-fungible-token bonus-pts)

(define-public (mint (amount uint) (user principal))
    (ft-mint? bonus-pts amount user)
)

(define-public (burn (amount uint) (user principal))
    (ft-burn? bonus-pts amount user)
)