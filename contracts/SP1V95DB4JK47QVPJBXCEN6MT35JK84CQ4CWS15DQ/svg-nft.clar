(define-non-fungible-token svg-nft uint)

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))

(define-data-var token-id-nonce uint u0)

(define-map token-svg-parts
    {token-id: uint, part-index: uint}
    (string-utf8 256)
)

(define-map token-part-count
    uint
    uint
)

(define-read-only (get-last-token-id)
    (ok (var-get token-id-nonce))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? svg-nft token-id))
)

(define-read-only (get-part-count (token-id uint))
    (ok (default-to u0 (map-get? token-part-count token-id)))
)

(define-read-only (get-svg-part (token-id uint) (part-index uint))
    (ok (map-get? token-svg-parts {token-id: token-id, part-index: part-index}))
)

(define-read-only (get-token-uri (token-id uint))
    (ok (default-to u"" (map-get? token-svg-parts {token-id: token-id, part-index: u0})))
)

(define-public (mint)
    (let
        (
            (new-id (+ (var-get token-id-nonce) u1))
        )
        (try! (nft-mint? svg-nft new-id tx-sender))
        (map-set token-part-count new-id u0)
        (var-set token-id-nonce new-id)
        (ok new-id)
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (nft-transfer? svg-nft token-id sender recipient)
    )
)

(define-public (add-svg-part (token-id uint) (svg-part (string-utf8 256)))
    (let
        (
            (owner (unwrap! (nft-get-owner? svg-nft token-id) ERR-NOT-FOUND))
            (current-count (default-to u0 (map-get? token-part-count token-id)))
        )
        (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
        (map-set token-svg-parts {token-id: token-id, part-index: current-count} svg-part)
        (map-set token-part-count token-id (+ current-count u1))
        (ok true)
    )
)

(define-public (update-svg-part (token-id uint) (part-index uint) (svg-part (string-utf8 256)))
    (let
        (
            (owner (unwrap! (nft-get-owner? svg-nft token-id) ERR-NOT-FOUND))
            (part-count (default-to u0 (map-get? token-part-count token-id)))
        )
        (asserts! (is-eq tx-sender owner) ERR-NOT-AUTHORIZED)
        (asserts! (< part-index part-count) ERR-NOT-FOUND)
        (ok (map-set token-svg-parts {token-id: token-id, part-index: part-index} svg-part))
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .svg-nft)
)
