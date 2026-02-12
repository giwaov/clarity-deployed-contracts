(define-fungible-token abstract-token)

(define-constant ERR-NOT-AUTHORIZED (err u401))

(define-data-var token-name (string-ascii 32) "AbstractToken")
(define-data-var token-symbol (string-ascii 10) "ABS")
(define-data-var token-decimals uint u6)

(define-map operator-approvals
    {owner: principal, operator: principal}
    bool
)

(define-map metadata-extensions
    (string-ascii 64)
    (buff 256)
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
    (ok (ft-get-balance abstract-token account))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply abstract-token))
)

(define-read-only (is-operator-for (owner principal) (operator principal))
    (ok (default-to false (map-get? operator-approvals {owner: owner, operator: operator})))
)

(define-read-only (get-metadata-extension (key (string-ascii 64)))
    (ok (map-get? metadata-extensions key))
)

(define-public (mint (amount uint) (recipient principal))
    (ft-mint? abstract-token amount recipient)
)

(define-public (transfer (amount uint) (sender principal) (recipient principal))
    (begin
        (asserts! (or (is-eq tx-sender sender) (default-to false (map-get? operator-approvals {owner: sender, operator: tx-sender}))) ERR-NOT-AUTHORIZED)
        (ft-transfer? abstract-token amount sender recipient)
    )
)

(define-public (burn (amount uint))
    (ft-burn? abstract-token amount tx-sender)
)

(define-public (authorize-operator (operator principal))
    (begin
        (ok (map-set operator-approvals {owner: tx-sender, operator: operator} true))
    )
)

(define-public (revoke-operator (operator principal))
    (begin
        (ok (map-delete operator-approvals {owner: tx-sender, operator: operator}))
    )
)

(define-public (set-metadata-extension (key (string-ascii 64)) (value (buff 256)))
    (begin
        (ok (map-set metadata-extensions key value))
    )
)

(define-public (batch-transfer (recipients (list 100 {to: principal, amount: uint})))
    (ok (fold batch-transfer-iter recipients true))
)

(define-private (batch-transfer-iter (recipient {to: principal, amount: uint}) (prev-result bool))
    (match (ft-transfer? abstract-token (get amount recipient) tx-sender (get to recipient))
        success prev-result
        error false
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .abstract-token)
)
