(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INVALID-SIGNATURE (err u402))
(define-constant ERR-ENDORSEMENT-USED (err u403))
(define-constant ERR-EXPIRED (err u410))

(define-map endorsements
    (buff 32)
    bool
)

(define-map endorsers
    principal
    bool
)

(define-data-var contract-owner principal tx-sender)

(define-read-only (is-endorser (account principal))
    (ok (default-to false (map-get? endorsers account)))
)

(define-read-only (is-endorsement-used (endorsement-hash (buff 32)))
    (ok (default-to false (map-get? endorsements endorsement-hash)))
)

(define-public (add-endorser (endorser principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (ok (map-set endorsers endorser true))
    )
)

(define-public (remove-endorser (endorser principal))
    (begin
        (asserts! (is-eq tx-sender (var-get contract-owner)) ERR-NOT-AUTHORIZED)
        (ok (map-delete endorsers endorser))
    )
)

(define-public (execute-endorsed-operation
    (target principal)
    (operation-data (buff 1024))
    (valid-until uint)
    (nonce (buff 32))
    (endorser principal)
)
    (let
        (
            (endorsement-hash (sha256 (concat
                (concat (unwrap-panic (to-consensus-buff? target)) operation-data)
                nonce
            )))
        )
        (asserts! (default-to false (map-get? endorsers endorser)) ERR-NOT-AUTHORIZED)
        (asserts! (not (default-to false (map-get? endorsements endorsement-hash))) ERR-ENDORSEMENT-USED)
        (asserts! (<= stacks-block-time valid-until) ERR-EXPIRED)
        (map-set endorsements endorsement-hash true)
        (ok true)
    )
)

(define-public (verify-endorsement
    (message (buff 1024))
    (endorser principal)
)
    (ok (default-to false (map-get? endorsers endorser)))
)

(define-read-only (get-contract-hash)
    (contract-hash? .endorsed-aa)
)
