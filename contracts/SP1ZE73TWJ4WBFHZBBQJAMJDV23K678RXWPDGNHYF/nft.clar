
;; title: nft
;; version: 1.0.0
;; summary: SIP-009 NFT Standard Implementation

(impl-trait .sip-009-nft-trait.nft-trait)

(define-non-fungible-token my-nft uint)

;; constant definitions
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-id-exists (err u102))

;; data vars
(define-data-var last-token-id uint u0)

;; public functions

(define-public (mint (recipient principal))
    (let
        (
            (token-id (+ (var-get last-token-id) u1))
        )
        ;; Check if sender is contract owner if we want to restrict minting
        ;; For this example, we'll allow public minting for simplicity or we can restrict it.
        ;; Let's make it unrestricted as requested "Mint, transfer..." usually implies testing these flows.
        ;; But standard NFTs usually have an owner. I'll check tx-sender is contract-owner.
        ;; User request did not specify, but usually "Mint" implies I can mint.
        ;; I will allow ANYONE to mint for this demo.
        (try! (nft-mint? my-nft token-id recipient))
        (var-set last-token-id token-id)
        (ok token-id)
    )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
    (begin
        (asserts! (is-eq tx-sender sender) err-not-token-owner)
        (nft-transfer? my-nft token-id sender recipient)
    )
)

;; read only functions

(define-read-only (get-last-token-id)
    (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
    (ok none) ;; No metadata for now
)

(define-read-only (get-owner (token-id uint))
    (ok (nft-get-owner? my-nft token-id))
)
