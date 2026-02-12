(define-non-fungible-token state-nft uint)

(define-map token-state
    uint
    {
        asset-type: (string-ascii 32),
        asset-value: uint,
        metadata-uri: (string-ascii 256),
        last-modified: uint
    }
)

(define-map token-uris uint (string-ascii 256))
(define-data-var token-id-nonce uint u0)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-invalid-token (err u102))

(define-read-only (get-last-token-id)
    (ok (var-get token-id-nonce))
)

(define-read-only (get-token-uri (token-id uint))
    (ok (map-get? token-uris token-id))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? state-nft token-id))
)

(define-read-only (get-state-fingerprint (token-id uint))
    (let
        (
            (state (unwrap! (map-get? token-state token-id) err-invalid-token))
        )
        (ok (sha256 (concat
            (concat
                (unwrap-panic (to-consensus-buff? (get asset-type state)))
                (unwrap-panic (to-consensus-buff? (get asset-value state)))
            )
            (concat
                (unwrap-panic (to-consensus-buff? (get metadata-uri state)))
                (unwrap-panic (to-consensus-buff? (get last-modified state)))
            )
        )))
    )
)

(define-read-only (get-token-state (token-id uint))
    (ok (map-get? token-state token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (nft-transfer? state-nft token-id sender recipient)
    )
)

(define-public (mint (recipient principal) (asset-type (string-ascii 32)) (asset-value uint) (metadata-uri (string-ascii 256)))
    (let
        (
            (new-token-id (+ (var-get token-id-nonce) u1))
        )
        (try! (nft-mint? state-nft new-token-id recipient))
        (map-set token-state new-token-id {
            asset-type: asset-type,
            asset-value: asset-value,
            metadata-uri: metadata-uri,
            last-modified: stacks-block-time
        })
        (var-set token-id-nonce new-token-id)
        (ok new-token-id)
    )
)

(define-public (update-state (token-id uint) (asset-type (string-ascii 32)) (asset-value uint) (metadata-uri (string-ascii 256)))
    (let
        (
            (token-owner (unwrap! (nft-get-owner? state-nft token-id) err-invalid-token))
        )
        (asserts! (is-eq tx-sender token-owner) err-not-token-owner)
        (ok (map-set token-state token-id {
            asset-type: asset-type,
            asset-value: asset-value,
            metadata-uri: metadata-uri,
            last-modified: stacks-block-time
        }))
    )
)

(define-public (set-token-uri (token-id uint) (uri (string-ascii 256)))
    (let
        (
            (token-owner (unwrap! (nft-get-owner? state-nft token-id) err-invalid-token))
        )
        (asserts! (is-eq tx-sender token-owner) err-not-token-owner)
        (ok (map-set token-uris token-id uri))
    )
)

(define-public (burn (token-id uint))
    (let
        (
            (token-owner (unwrap! (nft-get-owner? state-nft token-id) err-invalid-token))
        )
        (asserts! (is-eq tx-sender token-owner) err-not-token-owner)
        (map-delete token-state token-id)
        (nft-burn? state-nft token-id token-owner)
    )
)
