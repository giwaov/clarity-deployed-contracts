(define-fungible-token bindable-token)

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-ALREADY-BOUND (err u409))
(define-constant ERR-NOT-BOUND (err u404))

(define-data-var token-name (string-ascii 32) "BindableToken")
(define-data-var token-symbol (string-ascii 10) "BIND")
(define-data-var token-decimals uint u6)

(define-map bindings
    principal
    {
        bound-to: principal,
        binding-time: uint
    }
)

(define-map bound-balances
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
    (ok (ft-get-balance bindable-token account))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply bindable-token))
)

(define-read-only (get-binding (account principal))
    (ok (map-get? bindings account))
)

(define-read-only (is-bound (account principal))
    (ok (is-some (map-get? bindings account)))
)

(define-read-only (get-bound-balance (account principal))
    (ok (default-to u0 (map-get? bound-balances account)))
)

(define-public (mint (amount uint) (recipient principal))
    (ft-mint? bindable-token amount recipient)
)

(define-public (transfer (amount uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? bindings sender)) ERR-ALREADY-BOUND)
        (ft-transfer? bindable-token amount sender recipient)
    )
)

(define-public (bind-to (target principal) (amount uint))
    (begin
        (asserts! (is-none (map-get? bindings tx-sender)) ERR-ALREADY-BOUND)
        (asserts! (>= (ft-get-balance bindable-token tx-sender) amount) ERR-NOT-AUTHORIZED)
        (map-set bindings tx-sender {
            bound-to: target,
            binding-time: stacks-block-time
        })
        (map-set bound-balances tx-sender amount)
        (ok true)
    )
)

(define-public (unbind)
    (let
        (
            (binding (unwrap! (map-get? bindings tx-sender) ERR-NOT-BOUND))
        )
        (map-delete bindings tx-sender)
        (map-delete bound-balances tx-sender)
        (ok true)
    )
)

(define-public (transfer-bound (amount uint) (recipient principal))
    (let
        (
            (binding (unwrap! (map-get? bindings tx-sender) ERR-NOT-BOUND))
            (bound-amount (default-to u0 (map-get? bound-balances tx-sender)))
        )
        (asserts! (>= bound-amount amount) ERR-NOT-AUTHORIZED)
        (map-set bound-balances tx-sender (- bound-amount amount))
        (map-set bound-balances recipient (+ (default-to u0 (map-get? bound-balances recipient)) amount))
        (ok true)
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .binding-token)
)
