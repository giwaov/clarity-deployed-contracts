(impl-trait .sip-009-trait-v2.nft-trait)

(define-non-fungible-token my-nft-v2 uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-exists (err u102))

(define-data-var token-id-nonce uint u0)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (nft-transfer? my-nft-v2 token-id sender recipient)
    )
)

(define-read-only (get-last-token-id)
    (ok (var-get token-id-nonce))
)

(define-read-only (get-token-uri (token-id uint))
    (ok none)
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? my-nft-v2 token-id))
)

(define-public (mint (recipient principal))
    (let ((token-id (var-get token-id-nonce)))
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (try! (nft-mint? my-nft-v2 token-id recipient))
        (var-set token-id-nonce (+ token-id u1))
        (ok token-id)
    )
)
