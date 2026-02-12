(define-non-fungible-token physical-asset-nft uint)

(define-map asset-properties
    uint
    {
        token-issuer: principal,
        asset-holder: principal,
        storage-location: (string-utf8 256),
        terms: (string-utf8 512),
        jurisdiction: (string-ascii 64),
        declared-value: uint,
        redeemable: bool
    }
)

(define-map redemption-requests
    uint
    { requester: principal, timestamp: uint, approved: bool }
)

(define-map token-owner uint principal)

(define-data-var last-token-id uint u0)

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-not-found (err u101))
(define-constant err-not-redeemable (err u102))
(define-constant err-already-redeemed (err u103))
(define-constant err-not-holder (err u104))

(define-read-only (get-properties (token-id uint))
    (ok (map-get? asset-properties token-id))
)

(define-read-only (get-redemption-request (token-id uint))
    (ok (map-get? redemption-requests token-id))
)

(define-read-only (get-owner (token-id uint))
    (ok (map-get? token-owner token-id))
)

(define-public (mint 
    (recipient principal)
    (asset-holder principal)
    (storage-location (string-utf8 256))
    (terms (string-utf8 512))
    (jurisdiction (string-ascii 64))
    (declared-value uint)
)
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
        )
        (try! (nft-mint? physical-asset-nft token-id recipient))
        (map-set token-owner token-id recipient)
        (map-set asset-properties token-id
            {
                token-issuer: tx-sender,
                asset-holder: asset-holder,
                storage-location: storage-location,
                terms: terms,
                jurisdiction: jurisdiction,
                declared-value: declared-value,
                redeemable: true
            }
        )
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

(define-public (request-redemption (token-id uint))
    (let
        (
            (owner (unwrap! (map-get? token-owner token-id) err-not-found))
            (properties (unwrap! (map-get? asset-properties token-id) err-not-found))
        )
        (asserts! (is-eq tx-sender owner) err-not-owner)
        (asserts! (get redeemable properties) err-not-redeemable)
        (map-set redemption-requests token-id
            { requester: tx-sender, timestamp: stacks-block-time, approved: false }
        )
        (ok true)
    )
)

(define-public (approve-redemption (token-id uint))
    (let
        (
            (properties (unwrap! (map-get? asset-properties token-id) err-not-found))
            (request (unwrap! (map-get? redemption-requests token-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get asset-holder properties)) err-not-holder)
        (map-set redemption-requests token-id
            (merge request { approved: true })
        )
        (map-set asset-properties token-id
            (merge properties { redeemable: false })
        )
        (ok true)
    )
)

(define-public (update-storage-location (token-id uint) (new-location (string-utf8 256)))
    (let
        (
            (properties (unwrap! (map-get? asset-properties token-id) err-not-found))
        )
        (asserts! (is-eq tx-sender (get asset-holder properties)) err-not-holder)
        (map-set asset-properties token-id
            (merge properties { storage-location: new-location })
        )
        (ok true)
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (let
        (
            (properties (unwrap! (map-get? asset-properties token-id) err-not-found))
        )
        (asserts! (is-eq tx-sender sender) err-not-owner)
        (asserts! (get redeemable properties) err-already-redeemed)
        (try! (nft-transfer? physical-asset-nft token-id sender recipient))
        (map-set token-owner token-id recipient)
        (ok true)
    )
)
