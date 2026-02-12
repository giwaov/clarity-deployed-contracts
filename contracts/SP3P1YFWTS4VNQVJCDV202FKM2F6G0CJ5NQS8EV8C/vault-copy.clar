;; vault.clar
;; Simple STX Vault

(define-map balances principal uint)

(define-public (deposit (amount uint))
    (let
        (
            (current-bal (default-to u0 (map-get? balances tx-sender)))
        )
        (try! (stx-transfer? amount tx-sender (as-contract tx-sender)))
        (map-set balances tx-sender (+ current-bal amount))
        (ok true)
    )
)

(define-public (withdraw (amount uint))
    (let
        (
            (current-bal (unwrap! (map-get? balances tx-sender) (err u100)))
        )
        (asserts! (>= current-bal amount) (err u101))
        (try! (as-contract (stx-transfer? amount tx-sender tx-sender)))
        (map-set balances tx-sender (- current-bal amount))
        (ok true)
    )
)

(define-read-only (get-balance (user principal))
    (default-to u0 (map-get? balances user))
)
