(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-SOULBOUND (err u405))

(define-data-var token-id-nonce uint u0)

(define-map token-balances
    {owner: principal, slot: uint}
    uint
)

(define-map token-metadata
    {owner: principal, slot: uint}
    {
        issuer: principal,
        value: uint,
        valid-from: uint,
        valid-to: uint,
        soulbound: bool
    }
)

(define-map slot-approvals
    {owner: principal, slot: uint}
    principal
)

(define-read-only (balance-of (owner principal) (slot uint))
    (ok (default-to u0 (map-get? token-balances {owner: owner, slot: slot})))
)

(define-read-only (get-metadata (owner principal) (slot uint))
    (ok (map-get? token-metadata {owner: owner, slot: slot}))
)

(define-read-only (is-valid (owner principal) (slot uint))
    (match (map-get? token-metadata {owner: owner, slot: slot})
        metadata (ok (and
            (>= stacks-block-time (get valid-from metadata))
            (<= stacks-block-time (get valid-to metadata))
        ))
        (ok false)
    )
)

(define-read-only (is-soulbound (owner principal) (slot uint))
    (match (map-get? token-metadata {owner: owner, slot: slot})
        metadata (ok (get soulbound metadata))
        (ok false)
    )
)

(define-public (mint
    (to principal)
    (slot uint)
    (amount uint)
    (value uint)
    (valid-from uint)
    (valid-to uint)
    (soulbound bool)
)
    (begin
        (map-set token-balances {owner: to, slot: slot} 
            (+ amount (default-to u0 (map-get? token-balances {owner: to, slot: slot})))
        )
        (map-set token-metadata {owner: to, slot: slot} {
            issuer: tx-sender,
            value: value,
            valid-from: valid-from,
            valid-to: valid-to,
            soulbound: soulbound
        })
        (ok true)
    )
)

(define-public (transfer-from
    (from principal)
    (to principal)
    (slot uint)
    (amount uint)
)
    (let
        (
            (from-balance (default-to u0 (map-get? token-balances {owner: from, slot: slot})))
            (metadata (unwrap! (map-get? token-metadata {owner: from, slot: slot}) ERR-NOT-FOUND))
        )
        (asserts! (not (get soulbound metadata)) ERR-SOULBOUND)
        (asserts! (or (is-eq tx-sender from) (is-eq tx-sender (default-to from (map-get? slot-approvals {owner: from, slot: slot})))) ERR-NOT-AUTHORIZED)
        (asserts! (>= from-balance amount) ERR-NOT-AUTHORIZED)
        (map-set token-balances {owner: from, slot: slot} (- from-balance amount))
        (map-set token-balances {owner: to, slot: slot}
            (+ amount (default-to u0 (map-get? token-balances {owner: to, slot: slot})))
        )
        (ok true)
    )
)

(define-public (burn (slot uint) (amount uint))
    (let
        (
            (balance (default-to u0 (map-get? token-balances {owner: tx-sender, slot: slot})))
        )
        (asserts! (>= balance amount) ERR-NOT-AUTHORIZED)
        (map-set token-balances {owner: tx-sender, slot: slot} (- balance amount))
        (ok true)
    )
)

(define-public (approve (to principal) (slot uint))
    (begin
        (ok (map-set slot-approvals {owner: tx-sender, slot: slot} to))
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .soulbound-sft)
)
