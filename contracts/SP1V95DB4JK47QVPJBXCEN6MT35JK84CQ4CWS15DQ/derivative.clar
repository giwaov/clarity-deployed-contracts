(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-INVALID-STATE (err u400))

(define-data-var contract-id-nonce uint u0)

(define-map derivative-contracts
    uint
    {
        party-a: principal,
        party-b: principal,
        notional: uint,
        strike-price: uint,
        maturity: uint,
        contract-type: (string-ascii 20),
        state: (string-ascii 20),
        settlement-amount: uint
    }
)

(define-map contract-margins
    {contract-id: uint, party: principal}
    uint
)

(define-read-only (get-contract (contract-id uint))
    (ok (map-get? derivative-contracts contract-id))
)

(define-read-only (get-margin (contract-id uint) (party principal))
    (ok (default-to u0 (map-get? contract-margins {contract-id: contract-id, party: party})))
)

(define-read-only (get-contract-state (contract-id uint))
    (match (map-get? derivative-contracts contract-id)
        contract (ok (get state contract))
        ERR-NOT-FOUND
    )
)

(define-public (create-derivative
    (party-b principal)
    (notional uint)
    (strike-price uint)
    (maturity uint)
    (contract-type (string-ascii 20))
)
    (let
        (
            (new-id (+ (var-get contract-id-nonce) u1))
        )
        (map-set derivative-contracts new-id {
            party-a: tx-sender,
            party-b: party-b,
            notional: notional,
            strike-price: strike-price,
            maturity: maturity,
            contract-type: contract-type,
            state: "initiated",
            settlement-amount: u0
        })
        (var-set contract-id-nonce new-id)
        (ok new-id)
    )
)

(define-public (confirm-contract (contract-id uint))
    (let
        (
            (contract (unwrap! (map-get? derivative-contracts contract-id) ERR-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get party-b contract)) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (get state contract) "initiated") ERR-INVALID-STATE)
        (ok (map-set derivative-contracts contract-id (merge contract {state: "confirmed"})))
    )
)

(define-public (post-margin (contract-id uint) (amount uint))
    (let
        (
            (contract (unwrap! (map-get? derivative-contracts contract-id) ERR-NOT-FOUND))
            (current-margin (default-to u0 (map-get? contract-margins {contract-id: contract-id, party: tx-sender})))
        )
        (asserts! (or (is-eq tx-sender (get party-a contract)) (is-eq tx-sender (get party-b contract))) ERR-NOT-AUTHORIZED)
        (ok (map-set contract-margins {contract-id: contract-id, party: tx-sender} (+ current-margin amount)))
    )
)

(define-public (settle-contract (contract-id uint) (settlement-price uint))
    (let
        (
            (contract (unwrap! (map-get? derivative-contracts contract-id) ERR-NOT-FOUND))
            (settlement-amount (if (> settlement-price (get strike-price contract))
                (* (get notional contract) (- settlement-price (get strike-price contract)))
                u0
            ))
        )
        (asserts! (>= stacks-block-time (get maturity contract)) ERR-INVALID-STATE)
        (asserts! (is-eq (get state contract) "confirmed") ERR-INVALID-STATE)
        (map-set derivative-contracts contract-id (merge contract {
            state: "settled",
            settlement-amount: settlement-amount
        }))
        (ok settlement-amount)
    )
)

(define-public (withdraw-margin (contract-id uint))
    (let
        (
            (contract (unwrap! (map-get? derivative-contracts contract-id) ERR-NOT-FOUND))
            (margin (default-to u0 (map-get? contract-margins {contract-id: contract-id, party: tx-sender})))
        )
        (asserts! (is-eq (get state contract) "settled") ERR-INVALID-STATE)
        (map-delete contract-margins {contract-id: contract-id, party: tx-sender})
        (ok margin)
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .derivative)
)
