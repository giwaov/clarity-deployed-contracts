---
title: "Trait nova-market-core"
draft: true
---
```

;; nova-market-core.clar
;; Basic listing, buying, and selling logic for Nova Protocol NFTs.
;; CLARITY VERSION: 2

(use-trait nova-trait-non-fungible .nova-trait-non-fungible.nova-trait-non-fungible)

(define-map listings
    {token-contract: principal, token-id: uint}
    {
        seller: principal,
        price: uint,
        active: bool
    }
)

(define-constant ERR-NOT-OWNER (err u100))
(define-constant ERR-NOT-LISTED (err u101))
(define-constant ERR-WRONG-PRICE (err u102))

(define-public (list-asset (token-trait <nova-trait-non-fungible>) (token-id uint) (price uint))
    (let (
        (sender tx-sender)
        (contract (contract-of token-trait))
    )
    ;; Ensure owner
    (asserts! (is-eq (some sender) (unwrap! (contract-call? token-trait get-owner token-id) (err u103))) ERR-NOT-OWNER)
    
    ;; Transfer to marketplace to escrow
    (try! (contract-call? token-trait transfer token-id sender (as-contract tx-sender)))

    (map-set listings {token-contract: contract, token-id: token-id} {
        seller: sender,
        price: price,
        active: true
    })
    (ok true))
)

(define-public (buy-asset (token-trait <nova-trait-non-fungible>) (token-id uint))
    (let (
        (sender tx-sender)
        (contract (contract-of token-trait))
        (listing (unwrap! (map-get? listings {token-contract: contract, token-id: token-id}) ERR-NOT-LISTED))
    )
    (asserts! (get active listing) ERR-NOT-LISTED)
    
    (try! (stx-transfer? (get price listing) sender (get seller listing)))
    (try! (as-contract (contract-call? token-trait transfer token-id tx-sender sender)))

    (map-delete listings {token-contract: contract, token-id: token-id})
    (ok true))
)

(define-public (cancel-listing (token-trait <nova-trait-non-fungible>) (token-id uint))
    (let (
        (sender tx-sender)
        (contract (contract-of token-trait))
        (listing (unwrap! (map-get? listings {token-contract: contract, token-id: token-id}) ERR-NOT-LISTED))
    )
    (asserts! (is-eq sender (get seller listing)) ERR-NOT-OWNER)
    
    (try! (as-contract (contract-call? token-trait transfer token-id tx-sender sender)))
    (map-delete listings {token-contract: contract, token-id: token-id})
    (ok true))
)

```
