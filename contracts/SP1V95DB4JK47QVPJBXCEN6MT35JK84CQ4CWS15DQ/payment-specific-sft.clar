(define-fungible-token pbm-token)

(define-map token-metadata
    { token-id: uint }
    { 
        purpose: (string-ascii 64),
        issuer: principal,
        valid-until: uint,
        restrictions: (string-utf8 256)
    }
)

(define-map token-balances
    { token-id: uint, owner: principal }
    uint
)

(define-map compliance-guards
    principal
    bool
)

(define-data-var last-token-id uint u0)

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-invalid-amount (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-token-expired (err u103))
(define-constant err-not-compliant (err u104))
(define-constant err-not-found (err u105))

(define-read-only (get-balance (token-id uint) (owner principal))
    (ok (default-to u0 (map-get? token-balances { token-id: token-id, owner: owner })))
)

(define-read-only (get-token-metadata (token-id uint))
    (ok (map-get? token-metadata { token-id: token-id }))
)

(define-read-only (is-compliant (user principal))
    (ok (default-to false (map-get? compliance-guards user)))
)

(define-public (set-compliance-guard (user principal) (compliant bool))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-not-owner)
        (map-set compliance-guards user compliant)
        (ok true)
    )
)

(define-public (mint-pbm
    (recipient principal)
    (amount uint)
    (purpose (string-ascii 64))
    (valid-until uint)
    (restrictions (string-utf8 256))
)
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
            (is-recipient-compliant (default-to false (map-get? compliance-guards recipient)))
        )
        (asserts! (is-eq tx-sender contract-owner) err-not-owner)
        (asserts! is-recipient-compliant err-not-compliant)
        (asserts! (> amount u0) err-invalid-amount)
        (map-set token-metadata { token-id: token-id }
            {
                purpose: purpose,
                issuer: tx-sender,
                valid-until: valid-until,
                restrictions: restrictions
            }
        )
        (map-set token-balances { token-id: token-id, owner: recipient } amount)
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

(define-public (transfer-pbm (token-id uint) (amount uint) (sender principal) (recipient principal))
    (let
        (
            (sender-balance (default-to u0 (map-get? token-balances { token-id: token-id, owner: sender })))
            (recipient-balance (default-to u0 (map-get? token-balances { token-id: token-id, owner: recipient })))
            (metadata (unwrap! (map-get? token-metadata { token-id: token-id }) err-not-found))
            (is-recipient-compliant (default-to false (map-get? compliance-guards recipient)))
        )
        (asserts! (is-eq tx-sender sender) err-not-owner)
        (asserts! (>= sender-balance amount) err-insufficient-balance)
        (asserts! is-recipient-compliant err-not-compliant)
        (asserts! (< stacks-block-time (get valid-until metadata)) err-token-expired)
        (map-set token-balances { token-id: token-id, owner: sender } (- sender-balance amount))
        (map-set token-balances { token-id: token-id, owner: recipient } (+ recipient-balance amount))
        (ok true)
    )
)

(define-public (redeem-pbm (token-id uint) (amount uint))
    (let
        (
            (balance (default-to u0 (map-get? token-balances { token-id: token-id, owner: tx-sender })))
            (metadata (unwrap! (map-get? token-metadata { token-id: token-id }) err-not-found))
        )
        (asserts! (>= balance amount) err-insufficient-balance)
        (map-set token-balances { token-id: token-id, owner: tx-sender } (- balance amount))
        (ok true)
    )
)
