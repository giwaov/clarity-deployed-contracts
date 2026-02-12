(define-fungible-token share-token)

(define-map vault-assets
    principal
    { asset-address: principal, balance: uint }
)

(define-map asset-list
    uint
    principal
)

(define-map user-shares
    { user: principal, asset: principal }
    uint
)

(define-data-var total-assets uint u0)
(define-data-var asset-count uint u0)

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-invalid-amount (err u101))
(define-constant err-asset-not-found (err u102))
(define-constant err-insufficient-shares (err u103))

(define-read-only (get-vault-asset (asset principal))
    (ok (map-get? vault-assets asset))
)

(define-read-only (get-asset-count)
    (ok (var-get asset-count))
)

(define-read-only (get-user-shares (user principal) (asset principal))
    (ok (default-to u0 (map-get? user-shares { user: user, asset: asset })))
)

(define-read-only (get-total-assets)
    (ok (var-get total-assets))
)

(define-public (add-asset (asset-address principal))
    (let
        (
            (count (var-get asset-count))
        )
        (asserts! (is-eq tx-sender contract-owner) err-not-owner)
        (map-set vault-assets asset-address
            { asset-address: asset-address, balance: u0 }
        )
        (map-set asset-list count asset-address)
        (var-set asset-count (+ count u1))
        (ok true)
    )
)

(define-public (deposit (asset principal) (amount uint))
    (let
        (
            (asset-data (unwrap! (map-get? vault-assets asset) err-asset-not-found))
            (current-balance (get balance asset-data))
            (current-shares (default-to u0 (map-get? user-shares { user: tx-sender, asset: asset })))
        )
        (asserts! (> amount u0) err-invalid-amount)
        (map-set vault-assets asset
            { asset-address: asset, balance: (+ current-balance amount) }
        )
        (map-set user-shares { user: tx-sender, asset: asset }
            (+ current-shares amount)
        )
        (var-set total-assets (+ (var-get total-assets) amount))
        (ok true)
    )
)

(define-public (withdraw (asset principal) (amount uint))
    (let
        (
            (asset-data (unwrap! (map-get? vault-assets asset) err-asset-not-found))
            (current-balance (get balance asset-data))
            (current-shares (default-to u0 (map-get? user-shares { user: tx-sender, asset: asset })))
        )
        (asserts! (>= current-shares amount) err-insufficient-shares)
        (map-set vault-assets asset
            { asset-address: asset, balance: (- current-balance amount) }
        )
        (map-set user-shares { user: tx-sender, asset: asset }
            (- current-shares amount)
        )
        (var-set total-assets (- (var-get total-assets) amount))
        (ok true)
    )
)

(define-public (transfer-shares (asset principal) (amount uint) (recipient principal))
    (let
        (
            (sender-shares (default-to u0 (map-get? user-shares { user: tx-sender, asset: asset })))
            (recipient-shares (default-to u0 (map-get? user-shares { user: recipient, asset: asset })))
        )
        (asserts! (>= sender-shares amount) err-insufficient-shares)
        (map-set user-shares { user: tx-sender, asset: asset }
            (- sender-shares amount)
        )
        (map-set user-shares { user: recipient, asset: asset }
            (+ recipient-shares amount)
        )
        (ok true)
    )
)
