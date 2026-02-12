(define-non-fungible-token data-asset uint)

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-EXISTS (err u409))
(define-constant ERR-EXPIRED (err u410))

(define-data-var token-id-nonce uint u0)

(define-map token-metadata
    uint
    {
        commitment: (buff 32),
        size: uint,
        expire: uint,
        uploader: principal
    }
)

(define-map reader-permissions
    {token-id: uint, reader: principal}
    bool
)

(define-read-only (get-last-token-id)
    (ok (var-get token-id-nonce))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? data-asset token-id))
)

(define-read-only (get-metadata (token-id uint))
    (ok (map-get? token-metadata token-id))
)

(define-read-only (has-read-permission (token-id uint) (reader principal))
    (ok (default-to false (map-get? reader-permissions {token-id: token-id, reader: reader})))
)

(define-read-only (is-expired (token-id uint))
    (match (map-get? token-metadata token-id)
        metadata (ok (> stacks-block-time (get expire metadata)))
        ERR-NOT-FOUND
    )
)

(define-public (mint (commitment (buff 32)) (size uint) (expire uint))
    (let
        (
            (new-id (+ (var-get token-id-nonce) u1))
        )
        (try! (nft-mint? data-asset new-id tx-sender))
        (map-set token-metadata new-id {
            commitment: commitment,
            size: size,
            expire: expire,
            uploader: tx-sender
        })
        (var-set token-id-nonce new-id)
        (ok new-id)
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (nft-transfer? data-asset token-id sender recipient)
    )
)

(define-public (grant-read-permission (token-id uint) (reader principal))
    (let
        (
            (owner (unwrap! (nft-get-owner? data-asset token-id) ERR-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
        (ok (map-set reader-permissions {token-id: token-id, reader: reader} true))
    )
)

(define-public (revoke-read-permission (token-id uint) (reader principal))
    (let
        (
            (owner (unwrap! (nft-get-owner? data-asset token-id) ERR-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
        (ok (map-delete reader-permissions {token-id: token-id, reader: reader}))
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .data-nft)
)
