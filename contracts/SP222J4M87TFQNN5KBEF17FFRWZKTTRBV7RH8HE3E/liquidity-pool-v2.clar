(define-data-var total-liquidity uint u0)

(define-map user-liquidity principal uint)

(define-public (add-liquidity (amount uint))
    (begin
        (map-set user-liquidity tx-sender amount)
        (var-set total-liquidity (+ (var-get total-liquidity) amount))
        (ok true)
    )
)

(define-read-only (get-user-liquidity (user principal))
    (ok (default-to u0 (map-get? user-liquidity user)))
)

(define-read-only (get-total-liquidity)
    (ok (var-get total-liquidity))
)
