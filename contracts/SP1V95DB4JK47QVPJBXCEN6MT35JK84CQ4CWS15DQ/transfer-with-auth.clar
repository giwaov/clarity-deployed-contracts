(define-fungible-token auth-token)

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-INVALID-SIGNATURE (err u402))
(define-constant ERR-AUTHORIZATION-USED (err u403))

(define-data-var token-name (string-ascii 32) "AuthToken")
(define-data-var token-symbol (string-ascii 10) "AUTH")
(define-data-var token-decimals uint u6)

(define-map authorizations
    (buff 32)
    bool
)

(define-map balances
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
    (ok (ft-get-balance auth-token account))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply auth-token))
)

(define-read-only (is-authorization-used (auth-hash (buff 32)))
    (ok (default-to false (map-get? authorizations auth-hash)))
)

(define-public (mint (amount uint) (recipient principal))
    (ft-mint? auth-token amount recipient)
)

(define-public (transfer (amount uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (ft-transfer? auth-token amount sender recipient)
    )
)

(define-public (transfer-with-authorization
    (from principal)
    (to principal)
    (amount uint)
    (valid-after uint)
    (valid-before uint)
    (nonce (buff 32))
)
    (let
        (
            (auth-hash (sha256 (concat 
                (concat (unwrap-panic (to-consensus-buff? from)) (unwrap-panic (to-consensus-buff? to)))
                (concat (unwrap-panic (to-consensus-buff? amount)) nonce)
            )))
        )
        (asserts! (not (default-to false (map-get? authorizations auth-hash))) ERR-AUTHORIZATION-USED)
        (asserts! (>= stacks-block-time valid-after) ERR-NOT-AUTHORIZED)
        (asserts! (<= stacks-block-time valid-before) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq tx-sender from) ERR-INVALID-SIGNATURE)
        (map-set authorizations auth-hash true)
        (try! (ft-transfer? auth-token amount from to))
        (ok true)
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .transfer-with-auth)
)
