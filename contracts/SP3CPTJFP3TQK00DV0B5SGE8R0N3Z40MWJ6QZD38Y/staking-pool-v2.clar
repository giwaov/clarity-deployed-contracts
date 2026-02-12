;; staking-pool.clar
;; Pool funds to delegate

(define-map balances principal uint)

(define-public (deposit (amount uint))
    (begin
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set balances tx-sender (+ (default-to u0 (map-get? balances tx-sender)) amount))
        (ok true)
    )
)
