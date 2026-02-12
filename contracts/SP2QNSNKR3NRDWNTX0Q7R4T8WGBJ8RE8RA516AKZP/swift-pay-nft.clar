
;; SwiftPay NFT - Represents ownership of a payment stream
(impl-trait .nft-trait.nft-trait)

(define-non-fungible-token swift-pay-stream uint)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-OWNER (err u101))

;; Data Vars
(define-data-var last-id uint u0)
(define-data-var swift-pay-engine principal tx-sender)

;; Internal functions
(define-public (set-engine (new-engine principal))
    (begin
        (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
        (ok (var-set swift-pay-engine new-engine))
    )
)

;; Mint a new stream NFT (only called by engine)
(define-public (mint (recipient principal) (id uint))
    (begin
        (asserts! (is-eq contract-caller (var-get swift-pay-engine)) ERR-NOT-AUTHORIZED)
        (nft-mint? swift-pay-stream id recipient)
    )
)

;; Burn a stream NFT (only called by engine)
(define-public (burn (id uint))
    (begin
        (asserts! (is-eq contract-caller (var-get swift-pay-engine)) ERR-NOT-AUTHORIZED)
        (nft-burn? swift-pay-stream id (unwrap! (nft-get-owner? swift-pay-stream id) ERR-NOT-OWNER))
    )
)

;; SIP-009 Functions
(define-read-only (get-last-token-id)
    (ok (var-get last-id))
)

(define-read-only (get-token-uri (id uint))
    (ok none)
)

(define-read-only (get-owner (id uint))
    (ok (nft-get-owner? swift-pay-stream id))
)

(define-public (transfer (id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
        (nft-transfer? swift-pay-stream id sender recipient)
    )
)
;; End of file
;; End of file
