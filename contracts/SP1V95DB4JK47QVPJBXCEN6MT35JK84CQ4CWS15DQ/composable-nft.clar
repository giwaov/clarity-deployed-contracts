(define-non-fungible-token composable-token uint)

(define-constant ERR-NOT-AUTHORIZED (err u401))
(define-constant ERR-NOT-FOUND (err u404))
(define-constant ERR-ALREADY-OWNED (err u409))

(define-data-var token-id-nonce uint u0)

(define-map token-parent
    uint
    (optional uint)
)

(define-map child-tokens
    {parent: uint, child: uint}
    bool
)

(define-map owned-ft-balances
    {token-id: uint, asset-contract: principal}
    uint
)

(define-read-only (get-last-token-id)
    (ok (var-get token-id-nonce))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? composable-token token-id))
)

(define-read-only (get-parent (token-id uint))
    (ok (map-get? token-parent token-id))
)

(define-read-only (is-child-of (parent uint) (child uint))
    (ok (default-to false (map-get? child-tokens {parent: parent, child: child})))
)

(define-read-only (get-ft-balance (token-id uint) (asset-contract principal))
    (ok (default-to u0 (map-get? owned-ft-balances {token-id: token-id, asset-contract: asset-contract})))
)

(define-read-only (get-root-owner (token-id uint))
    (ok (nft-get-owner? composable-token token-id))
)

(define-public (mint)
    (let
        (
            (new-id (+ (var-get token-id-nonce) u1))
        )
        (try! (nft-mint? composable-token new-id tx-sender))
        (map-set token-parent new-id none)
        (var-set token-id-nonce new-id)
        (ok new-id)
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? token-parent token-id)) ERR-ALREADY-OWNED)
        (nft-transfer? composable-token token-id sender recipient)
    )
)

(define-public (attach-child (parent-id uint) (child-id uint))
    (let
        (
            (parent-owner (unwrap! (nft-get-owner? composable-token parent-id) ERR-NOT-FOUND))
            (child-owner (unwrap! (nft-get-owner? composable-token child-id) ERR-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender child-owner) ERR-NOT-AUTHORIZED)
        (asserts! (is-none (map-get? token-parent child-id)) ERR-ALREADY-OWNED)
        (map-set token-parent child-id (some parent-id))
        (map-set child-tokens {parent: parent-id, child: child-id} true)
        (try! (nft-transfer? composable-token child-id child-owner parent-owner))
        (ok true)
    )
)

(define-public (detach-child (parent-id uint) (child-id uint) (recipient principal))
    (let
        (
            (parent-owner (unwrap! (nft-get-owner? composable-token parent-id) ERR-NOT-FOUND))
        )
        (asserts! (is-eq tx-sender parent-owner) ERR-NOT-AUTHORIZED)
        (asserts! (is-eq (map-get? token-parent child-id) (some (some parent-id))) ERR-NOT-FOUND)
        (map-set token-parent child-id none)
        (map-delete child-tokens {parent: parent-id, child: child-id})
        (try! (nft-transfer? composable-token child-id parent-owner recipient))
        (ok true)
    )
)

(define-read-only (get-contract-hash)
    (contract-hash? .composable-nft)
)
