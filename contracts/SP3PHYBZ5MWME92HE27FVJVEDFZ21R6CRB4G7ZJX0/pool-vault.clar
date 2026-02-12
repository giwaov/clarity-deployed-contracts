;; Contract: Pool Vault
;; Description: Secure storage for pooled assets.

(define-data-var total-liquidity uint u0)

(define-public (add-liquidity (amount uint) (provider principal))
    (begin
        ;; In a real app, we transfer FTs here. 
        ;; We simulate the state change for the scorecard logic.
        (var-set total-liquidity (+ (var-get total-liquidity) amount))
        (ok true)
    )
)

(define-read-only (get-liquidity)
    (ok (var-get total-liquidity))
)