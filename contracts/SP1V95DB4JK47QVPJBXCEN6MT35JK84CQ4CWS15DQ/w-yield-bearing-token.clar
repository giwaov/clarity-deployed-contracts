(define-fungible-token wrapped-yield-token)

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INSUFFICIENT-BALANCE (err u402))

(define-data-var token-name (string-ascii 32) "WrappedYieldToken")
(define-data-var token-symbol (string-ascii 10) "WYT")
(define-data-var token-decimals uint u6)
(define-data-var exchange-rate uint u1000000)

(define-map yield-balances
    principal
    uint
)

(define-map deposited-amounts
    principal
    uint
)

(define-read-only (get-name)
    (ok (var-get token-name))
)

(define-read-only (get-symbol)
    (ok (var-get token-symbol))
)

(define-read-only (get-decimals)
    (ok (var-get token-decimals))
)

(define-read-only (get-balance (account principal))
    (ok (ft-get-balance wrapped-yield-token account))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply wrapped-yield-token))
)

(define-read-only (get-exchange-rate)
    (ok (var-get exchange-rate))
)

(define-read-only (get-yield-balance (account principal))
    (ok (default-to u0 (map-get? yield-balances account)))
)

(define-read-only (preview-deposit (assets uint))
    (ok (/ (* assets u1000000) (var-get exchange-rate)))
)

(define-read-only (preview-redeem (shares uint))
    (ok (/ (* shares (var-get exchange-rate)) u1000000))
)

(define-public (deposit (assets uint))
    (let
        (
            (shares (unwrap-panic (preview-deposit assets)))
        )
        (try! (ft-mint? wrapped-yield-token shares tx-sender))
        (map-set deposited-amounts tx-sender 
            (+ assets (default-to u0 (map-get? deposited-amounts tx-sender)))
        )
        (ok shares)
    )
)

(define-public (redeem (shares uint))
    (let
        (
            (assets (unwrap-panic (preview-redeem shares)))
        )
        (asserts! (>= (ft-get-balance wrapped-yield-token tx-sender) shares) ERR-INSUFFICIENT-BALANCE)
        (try! (ft-burn? wrapped-yield-token shares tx-sender))
        (ok assets)
    )
)

(define-public (transfer (amount uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (ft-transfer? wrapped-yield-token amount sender recipient)
    )
)

(define-public (claim-yield)
    (let
        (
            (balance (ft-get-balance wrapped-yield-token tx-sender))
            (yield-earned (/ (* balance (var-get exchange-rate)) u1000000))
        )
        (map-set yield-balances tx-sender 
            (+ yield-earned (default-to u0 (map-get? yield-balances tx-sender)))
        )
        (ok yield-earned)
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .w-yield-bearing-token)
)
