(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))

(define-map royalty-payments
    {nft-contract: principal, token-id: uint}
    {
        recipient: principal,
        amount: uint,
        paid: uint,
        currency: principal
    }
)

(define-map payment-history
    {nft-contract: principal, token-id: uint, payer: principal}
    uint
)

(define-map registry-operators
    principal
    bool
)

(define-data-var registry-owner principal tx-sender)

(define-read-only (get-royalty-info (nft-contract principal) (token-id uint))
    (ok (map-get? royalty-payments {nft-contract: nft-contract, token-id: token-id}))
)

(define-read-only (get-payment-history (nft-contract principal) (token-id uint) (payer principal))
    (ok (default-to u0 (map-get? payment-history {nft-contract: nft-contract, token-id: token-id, payer: payer})))
)

(define-read-only (is-operator (account principal))
    (ok (default-to false (map-get? registry-operators account)))
)

(define-public (register-royalty
    (nft-contract principal)
    (token-id uint)
    (recipient principal)
    (amount uint)
    (currency principal)
)
    (begin
        (asserts! (or (is-eq tx-sender (var-get registry-owner)) (default-to false (map-get? registry-operators tx-sender))) ERR-NOT-AUTHORIZED)
        (ok (map-set royalty-payments {nft-contract: nft-contract, token-id: token-id} {
            recipient: recipient,
            amount: amount,
            paid: u0,
            currency: currency
        }))
    )
)

(define-public (record-payment
    (nft-contract principal)
    (token-id uint)
    (payment-amount uint)
)
    (let
        (
            (royalty (unwrap! (map-get? royalty-payments {nft-contract: nft-contract, token-id: token-id}) ERR-NOT-FOUND))
            (current-paid (get paid royalty))
            (payer-history (default-to u0 (map-get? payment-history {nft-contract: nft-contract, token-id: token-id, payer: tx-sender})))
        )
        (map-set royalty-payments {nft-contract: nft-contract, token-id: token-id}
            (merge royalty {paid: (+ current-paid payment-amount)})
        )
        (map-set payment-history {nft-contract: nft-contract, token-id: token-id, payer: tx-sender}
            (+ payer-history payment-amount)
        )
        (ok true)
    )
)

(define-public (update-royalty-recipient
    (nft-contract principal)
    (token-id uint)
    (new-recipient principal)
)
    (let
        (
            (royalty (unwrap! (map-get? royalty-payments {nft-contract: nft-contract, token-id: token-id}) ERR-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get recipient royalty)) ERR-NOT-AUTHORIZED)
        (ok (map-set royalty-payments {nft-contract: nft-contract, token-id: token-id}
            (merge royalty {recipient: new-recipient})
        ))
    )
)

(define-public (add-operator (operator principal))
    (begin
        (asserts! (is-eq tx-sender (var-get registry-owner)) ERR-NOT-AUTHORIZED)
        (ok (map-set registry-operators operator true))
    )
)

(define-public (remove-operator (operator principal))
    (begin
        (asserts! (is-eq tx-sender (var-get registry-owner)) ERR-NOT-AUTHORIZED)
        (ok (map-delete registry-operators operator))
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .royalty-payment-registry)
)
