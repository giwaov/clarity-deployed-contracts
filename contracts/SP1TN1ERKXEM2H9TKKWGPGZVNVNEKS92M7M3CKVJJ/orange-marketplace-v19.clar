(use-trait nft-trait .orange-sip009-nft-trait-v19.nft-trait)
(use-trait ft-trait .orange-sip010-ft-trait-v19.ft-trait)

(define-map listings {token-id: uint, nft-asset-contract: principal} {price: uint, seller: principal})

(define-public (list-asset (nft-asset-contract <nft-trait>) (token-id uint) (price uint))
    (begin
        (try! (contract-call? nft-asset-contract transfer token-id tx-sender current-contract))
        (map-set listings {token-id: token-id, nft-asset-contract: (contract-of nft-asset-contract)} {price: price, seller: tx-sender})
        (ok true)
    )
)

(define-public (buy-asset (nft-asset-contract <nft-trait>) (token-id uint))
    (let
        (
            (listing (unwrap! (map-get? listings {token-id: token-id, nft-asset-contract: (contract-of nft-asset-contract)}) (err u404)))
            (price (get price listing))
            (seller (get seller listing))
            (buyer tx-sender)
        )
        (begin
            (try! (stx-transfer? price buyer seller))
            ;; Use direct transfer: the NFT v19 contract authorizes contract-caller
            (try! (contract-call? nft-asset-contract transfer token-id current-contract buyer))
            (map-delete listings {token-id: token-id, nft-asset-contract: (contract-of nft-asset-contract)})
            (ok true)
        )
    )
)
