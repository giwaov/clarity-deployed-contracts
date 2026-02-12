---
title: "Trait marketplace-v2"
draft: true
---
```
;; marketplace.clar
;; Simple NFT marketplace logic

(use-trait nft-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

(define-map listings { token-id: uint, contract: principal } { price: uint, seller: principal })

(define-public (list-item (nft <nft-trait>) (token-id uint) (price uint))
    (let
        (
            (contract (contract-of nft))
        )
        (try! (contract-call? nft transfer token-id tx-sender (as-contract tx-sender)))
        (map-set listings { token-id: token-id, contract: contract } { price: price, seller: tx-sender })
        (ok true)
    )
)

(define-public (buy-item (nft <nft-trait>) (token-id uint))
    (let
        (
            (contract (contract-of nft))
            (listing (unwrap! (map-get? listings { token-id: token-id, contract: contract }) (err u100)))
            (price (get price listing))
            (seller (get seller listing))
        )
        (try! (stx-transfer? price tx-sender seller))
        (try! (as-contract (contract-call? nft transfer token-id tx-sender tx-sender)))
        (map-delete listings { token-id: token-id, contract: contract })
        (ok true)
    )
)

```
