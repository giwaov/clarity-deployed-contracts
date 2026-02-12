(define-fungible-token semi-fungible-token)

(define-map token-supplies uint uint)
(define-map token-balances { token-id: uint, owner: principal } uint)
(define-map token-exists uint bool)
(define-map token-uris uint (string-ascii 256))

(define-data-var token-id-nonce uint u0)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-authorized (err u101))
(define-constant err-insufficient-balance (err u102))
(define-constant err-token-not-exists (err u103))

(define-read-only (get-balance (token-id uint) (account principal))
    (ok (default-to u0 (map-get? token-balances { token-id: token-id, owner: account })))
)

(define-read-only (get-total-supply (token-id uint))
    (ok (default-to u0 (map-get? token-supplies token-id)))
)

(define-read-only (exists (token-id uint))
    (ok (default-to false (map-get? token-exists token-id)))
)

(define-read-only (get-token-uri (token-id uint))
    (ok (map-get? token-uris token-id))
)

(define-public (transfer (token-id uint) (amount uint) (sender principal) (recipient principal))
    (let
        (
            (sender-balance (default-to u0 (map-get? token-balances { token-id: token-id, owner: sender })))
        )
        (asserts! (is-eq tx-sender sender) err-not-authorized)
        (asserts! (>= sender-balance amount) err-insufficient-balance)
        (update-balance token-id sender (- sender-balance amount))
        (update-balance token-id recipient (+ (default-to u0 (map-get? token-balances { token-id: token-id, owner: recipient })) amount))
        (print { type: "transfer", token-id: token-id, amount: amount, sender: sender, recipient: recipient })
        (ok true)
    )
)

(define-public (mint (token-id uint) (amount uint) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set token-exists token-id true)
        (map-set token-supplies token-id (+ (default-to u0 (map-get? token-supplies token-id)) amount))
        (update-balance token-id recipient (+ (default-to u0 (map-get? token-balances { token-id: token-id, owner: recipient })) amount))
        (print { type: "mint", token-id: token-id, amount: amount, recipient: recipient })
        (ok true)
    )
)

(define-public (burn (token-id uint) (amount uint) (owner principal))
    (let
        (
            (owner-balance (default-to u0 (map-get? token-balances { token-id: token-id, owner: owner })))
        )
        (asserts! (is-eq tx-sender owner) err-not-authorized)
        (asserts! (>= owner-balance amount) err-insufficient-balance)
        (map-set token-supplies token-id (- (default-to u0 (map-get? token-supplies token-id)) amount))
        (update-balance token-id owner (- owner-balance amount))
        (print { type: "burn", token-id: token-id, amount: amount, owner: owner })
        (ok true)
    )
)

(define-private (update-balance (token-id uint) (account principal) (new-balance uint))
    (begin
        (map-set token-balances { token-id: token-id, owner: account } new-balance)
        true
    )
)

(define-public (set-token-uri (token-id uint) (uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set token-uris token-id uri))
    )
)

(define-public (batch-transfer (transfers (list 10 { token-id: uint, amount: uint, recipient: principal })))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map process-transfer transfers))
    )
)

(define-private (process-transfer (transfer-data { token-id: uint, amount: uint, recipient: principal }))
    true
)
