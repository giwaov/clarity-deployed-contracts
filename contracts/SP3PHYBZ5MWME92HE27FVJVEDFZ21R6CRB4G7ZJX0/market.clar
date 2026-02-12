;; Contract: Marketplace
;; Description: Allows listing and buying the NFT.

(define-map listings uint {price: uint, seller: principal})

(define-public (list-item (token-id uint) (price uint))
    (begin
        ;; Check ownership would happen here via contract-call
        (map-set listings token-id {price: price, seller: tx-sender})
        (ok "Item Listed")
    )
)

(define-public (buy-item (token-id uint))
    (let
        (
            (listing (unwrap! (map-get? listings token-id) (err u404)))
            (price (get price listing))
            (seller (get seller listing))
        )
        ;; 1. Transfer STX from buyer to seller
        (try! (stx-transfer? price tx-sender seller))
        
        ;; 2. Call the NFT contract to transfer the asset
        ;; Note: The NFT contract needs to allow this contract to transfer
        (as-contract (contract-call? .art-token transfer token-id seller tx-sender))
    )
)