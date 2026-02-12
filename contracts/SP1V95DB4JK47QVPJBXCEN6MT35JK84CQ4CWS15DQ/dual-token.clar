(define-fungible-token base-token)
(define-non-fungible-token mirror-nft uint)

(define-map ft-balances principal uint)
(define-map nft-owners uint principal)
(define-map skip-nft principal bool)

(define-data-var total-supply uint u0)
(define-data-var last-nft-id uint u0)
(define-data-var units-per-nft uint u1000000)

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-insufficient-balance (err u101))
(define-constant err-nft-not-found (err u102))
(define-constant err-invalid-amount (err u103))

(define-read-only (get-balance (user principal))
    (ok (default-to u0 (map-get? ft-balances user)))
)

(define-read-only (get-nft-owner (token-id uint))
    (ok (map-get? nft-owners token-id))
)

(define-read-only (get-skip-nft (user principal))
    (ok (default-to false (map-get? skip-nft user)))
)

(define-read-only (get-total-supply)
    (ok (var-get total-supply))
)

(define-public (set-skip-nft (skip bool))
    (begin
        (map-set skip-nft tx-sender skip)
        (ok true)
    )
)

(define-public (mint (recipient principal) (amount uint))
    (let
        (
            (current-balance (default-to u0 (map-get? ft-balances recipient)))
        )
        (asserts! (is-eq tx-sender contract-owner) err-not-owner)
        (asserts! (> amount u0) err-invalid-amount)
        (try! (ft-mint? base-token amount recipient))
        (map-set ft-balances recipient (+ current-balance amount))
        (var-set total-supply (+ (var-get total-supply) amount))
        (ok true)
    )
)

(define-public (transfer (amount uint) (sender principal) (recipient principal))
    (let
        (
            (sender-balance (default-to u0 (map-get? ft-balances sender)))
            (recipient-balance (default-to u0 (map-get? ft-balances recipient)))
        )
        (asserts! (is-eq tx-sender sender) err-not-owner)
        (asserts! (>= sender-balance amount) err-insufficient-balance)
        (try! (ft-transfer? base-token amount sender recipient))
        (map-set ft-balances sender (- sender-balance amount))
        (map-set ft-balances recipient (+ recipient-balance amount))
        (ok true)
    )
)

(define-public (mint-nft (recipient principal))
    (let
        (
            (token-id (+ (var-get last-nft-id) u1))
        )
        (asserts! (is-eq tx-sender contract-owner) err-not-owner)
        (try! (nft-mint? mirror-nft token-id recipient))
        (map-set nft-owners token-id recipient)
        (var-set last-nft-id token-id)
        (ok token-id)
    )
)

(define-public (transfer-nft (token-id uint) (sender principal) (recipient principal))
    (let
        (
            (owner (unwrap! (map-get? nft-owners token-id) err-nft-not-found))
        )
        (asserts! (is-eq tx-sender sender) err-not-owner)
        (asserts! (is-eq owner sender) err-not-owner)
        (try! (nft-transfer? mirror-nft token-id sender recipient))
        (map-set nft-owners token-id recipient)
        (ok true)
    )
)

(define-public (burn (amount uint))
    (let
        (
            (balance (default-to u0 (map-get? ft-balances tx-sender)))
        )
        (asserts! (>= balance amount) err-insufficient-balance)
        (try! (ft-burn? base-token amount tx-sender))
        (map-set ft-balances tx-sender (- balance amount))
        (var-set total-supply (- (var-get total-supply) amount))
        (ok true)
    )
)
