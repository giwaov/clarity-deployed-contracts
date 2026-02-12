;; soulbound-nft.clar
;; NFT that cannot be transferred once minted
(use-trait nft-trait .nft-trait.nft-trait)
(impl-trait .nft-trait.nft-trait)

(define-non-fungible-token soulbound-nft uint)
(define-data-var last-token-id uint u0)
(define-constant contract-owner tx-sender)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (err u100) ;; ERR_NOT_TRANSFERABLE
)

(define-public (mint (recipient principal))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
        )
        (asserts! (is-eq tx-sender contract-owner) (err u101))
        (try! (nft-mint? soulbound-nft token-id recipient))
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

(define-public (burn (token-id uint))
    (begin
        (asserts! (is-eq tx-sender (unwrap! (nft-get-owner? soulbound-nft token-id) (err u404))) (err u102))
        (nft-burn? soulbound-nft token-id tx-sender)
    )
)

(define-read-only (get-last-token-id) (ok (var-get last-token-id)))
(define-read-only (get-owner (token-id uint)) (ok (nft-get-owner? soulbound-nft token-id)))
(define-read-only (get-token-uri (token-id uint)) (ok none))
