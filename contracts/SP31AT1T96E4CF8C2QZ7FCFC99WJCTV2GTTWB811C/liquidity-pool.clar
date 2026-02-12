(define-map liquidity-providers principal uint)

(define-public (pledge-liquidity (amount uint))
    (let
        (
            (current (default-to u0 (map-get? liquidity-providers tx-sender)))
        )
        (map-set liquidity-providers tx-sender (+ current amount))
        (ok true)
    )
)

(define-read-only (get-pledge (who principal))
    (ok (default-to u0 (map-get? liquidity-providers who)))
)
