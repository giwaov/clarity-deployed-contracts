(define-non-fungible-token multiverse-nft uint)

(define-data-var token-id-nonce uint u0)

(define-map delegate-tokens
    { multiverse-token-id: uint, index: uint }
    { contract-address: principal, token-id: uint, quantity: uint }
)

(define-map delegate-count
    { multiverse-token-id: uint }
    { count: uint }
)

(define-map token-uris uint (string-ascii 256))

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-invalid-token (err u102))
(define-constant err-transfer-failed (err u103))
(define-constant err-invalid-delegate (err u104))

(define-read-only (get-last-token-id)
    (ok (var-get token-id-nonce))
)

(define-read-only (get-token-uri (token-id uint))
    (ok (map-get? token-uris token-id))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? multiverse-nft token-id))
)

(define-read-only (get-delegate-tokens (multiverse-token-id uint))
    (let
        (
            (count-data (default-to { count: u0 } (map-get? delegate-count { multiverse-token-id: multiverse-token-id })))
            (total-count (get count count-data))
        )
        (ok (map get-delegate-token-by-index (list u0 u1 u2 u3 u4 u5 u6 u7 u8 u9)))
    )
)

(define-private (get-delegate-token-by-index (index uint))
    (default-to
        { contract-address: contract-owner, token-id: u0, quantity: u0 }
        (map-get? delegate-tokens { multiverse-token-id: u0, index: index })
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (nft-transfer? multiverse-nft token-id sender recipient)
    )
)

(define-public (init-bundle (delegates (list 10 { contract-address: principal, token-id: uint, quantity: uint })))
    (let
        (
            (new-token-id (+ (var-get token-id-nonce) u1))
        )
        (try! (nft-mint? multiverse-nft new-token-id tx-sender))
        (var-set token-id-nonce new-token-id)
        (map-set delegate-count { multiverse-token-id: new-token-id } { count: (len delegates) })
        (map store-delegate-data delegates)
        (ok new-token-id)
    )
)

(define-private (store-delegate-data (delegate { contract-address: principal, token-id: uint, quantity: uint }))
    true
)

(define-public (bundle (multiverse-token-id uint) (delegates (list 10 { contract-address: principal, token-id: uint, quantity: uint })))
    (let
        (
            (token-owner (unwrap! (nft-get-owner? multiverse-nft multiverse-token-id) err-invalid-token))
        )
        (asserts! (is-eq tx-sender token-owner) err-not-token-owner)
        (ok true)
    )
)

(define-public (unbundle (multiverse-token-id uint) (delegates (list 10 { contract-address: principal, token-id: uint, quantity: uint })))
    (let
        (
            (token-owner (unwrap! (nft-get-owner? multiverse-nft multiverse-token-id) err-invalid-token))
        )
        (asserts! (is-eq tx-sender token-owner) err-not-token-owner)
        (ok true)
    )
)

(define-public (set-token-uri (token-id uint) (uri (string-ascii 256)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (ok (map-set token-uris token-id uri))
    )
)

(define-public (burn (token-id uint))
    (let
        (
            (token-owner (unwrap! (nft-get-owner? multiverse-nft token-id) err-invalid-token))
        )
        (asserts! (is-eq tx-sender token-owner) err-not-token-owner)
        (nft-burn? multiverse-nft token-id token-owner)
    )
)
