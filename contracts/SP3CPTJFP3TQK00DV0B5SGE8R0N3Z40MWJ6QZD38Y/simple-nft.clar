;; simple-nft.clar
;; A simple SIP-009 Non-Fungible Token
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

(define-non-fungible-token simple-nft uint)
(define-data-var last-token-id uint u0)
(define-constant contract-owner tx-sender)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) (err u100))
        (nft-transfer? simple-nft token-id sender recipient)
    )
)

(define-public (mint (recipient principal))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
        )
        (asserts! (is-eq tx-sender contract-owner) (err u101))
        (try! (nft-mint? simple-nft token-id recipient))
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? simple-nft token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (ok none)
)
