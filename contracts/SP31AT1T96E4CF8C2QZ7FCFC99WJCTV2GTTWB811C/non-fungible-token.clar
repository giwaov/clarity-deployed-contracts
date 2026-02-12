(impl-trait .sip-009-trait.sip-009-trait)

(define-non-fungible-token my-nft uint)

(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))

(define-data-var last-token-id uint u0)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (try! (nft-transfer? my-nft token-id sender recipient))
        (ok true)
    )
)

(define-public (mint (recipient principal))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
        )
        (try! (nft-mint? my-nft token-id recipient))
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (ok none)
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? my-nft token-id))
)
