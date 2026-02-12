(define-fungible-token physical-backed-token)

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))

(define-data-var token-name (string-ascii 32) "PhysicalBackedToken")
(define-data-var token-symbol (string-ascii 10) "PBT")
(define-data-var token-decimals uint u0)

(define-map physical-assets
    (buff 32)
    {
        token-amount: uint,
        owner: principal,
        verified: bool,
        metadata-uri: (string-utf8 256)
    }
)

(define-map asset-to-chip
    (buff 32)
    (buff 65)
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
    (ok (ft-get-balance physical-backed-token account))
)

(define-read-only (get-total-supply)
    (ok (ft-get-supply physical-backed-token))
)

(define-read-only (get-physical-asset (asset-id (buff 32)))
    (ok (map-get? physical-assets asset-id))
)

(define-read-only (is-asset-verified (asset-id (buff 32)))
    (match (map-get? physical-assets asset-id)
        asset (ok (get verified asset))
        (ok false)
    )
)

(define-public (mint-with-physical-asset
    (asset-id (buff 32))
    (chip-signature (buff 65))
    (amount uint)
    (metadata-uri (string-utf8 256))
)
    (begin
        (asserts! (is-none (map-get? physical-assets asset-id)) ERR-NOT-FOUND)
        (map-set physical-assets asset-id {
            token-amount: amount,
            owner: tx-sender,
            verified: true,
            metadata-uri: metadata-uri
        })
        (map-set asset-to-chip asset-id chip-signature)
        (try! (ft-mint? physical-backed-token amount tx-sender))
        (ok asset-id)
    )
)

(define-public (verify-asset-ownership
    (asset-id (buff 32))
    (chip-signature (buff 65))
    (message (buff 256))
)
    (let
        (
            (asset (unwrap! (map-get? physical-assets asset-id) ERR-NOT-FOUND))
            (stored-chip (unwrap! (map-get? asset-to-chip asset-id) ERR-NOT-FOUND))
        )
        (ok (is-eq stored-chip chip-signature))
    )
)

(define-public (transfer (amount uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (ft-transfer? physical-backed-token amount sender recipient)
    )
)

(define-public (burn-and-redeem (asset-id (buff 32)))
    (let
        (
            (asset (unwrap! (map-get? physical-assets asset-id) ERR-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender (get owner asset)) ERR-NOT-AUTHORIZED)
        (try! (ft-burn? physical-backed-token (get token-amount asset) tx-sender))
        (map-delete physical-assets asset-id)
        (map-delete asset-to-chip asset-id)
        (ok true)
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .physical-item-backed-token)
)
