---
title: "Trait nft-marketplace"
draft: true
---
```
;; NFT Marketplace
;; Buy, sell, and trade NFTs with escrow protection

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u500))
(define-constant err-listing-not-found (err u501))
(define-constant err-already-listed (err u502))
(define-constant err-not-for-sale (err u503))
(define-constant err-insufficient-payment (err u504))

(define-map listings
    { nft-id: uint }
    {
        seller: principal,
        price: uint,
        active: bool
    }
)

(define-map nft-owners
    { nft-id: uint }
    principal
)

(define-data-var listing-counter uint u0)

;; List NFT for sale
(define-public (list-nft (nft-id uint) (price uint))
    (let
        (
            (current-owner (unwrap! (map-get? nft-owners { nft-id: nft-id }) err-not-owner))
        )
        (asserts! (is-eq tx-sender current-owner) err-not-owner)
        (asserts! (is-none (map-get? listings { nft-id: nft-id })) err-already-listed)
        
        (map-set listings
            { nft-id: nft-id }
            {
                seller: tx-sender,
                price: price,
                active: true
            }
        )
        (ok true)
    )
)

;; Buy NFT
(define-public (buy-nft (nft-id uint))
    (let
        (
            (listing (unwrap! (map-get? listings { nft-id: nft-id }) err-listing-not-found))
        )
        (asserts! (get active listing) err-not-for-sale)
        
        ;; Transfer payment to seller
        (try! (stx-transfer? (get price listing) tx-sender (get seller listing)))
        
        ;; Transfer NFT ownership
        (map-set nft-owners
            { nft-id: nft-id }
            tx-sender
        )
        
        ;; Mark listing as inactive
        (map-set listings
            { nft-id: nft-id }
            (merge listing { active: false })
        )
        
        (ok true)
    )
)

;; Cancel listing
(define-public (cancel-listing (nft-id uint))
    (let
        (
            (listing (unwrap! (map-get? listings { nft-id: nft-id }) err-listing-not-found))
        )
        (asserts! (is-eq tx-sender (get seller listing)) err-not-owner)
        
        (map-set listings
            { nft-id: nft-id }
            (merge listing { active: false })
        )
        (ok true)
    )
)

;; Mint NFT (for demo)
(define-public (mint-nft)
    (let
        (
            (nft-id (+ (var-get listing-counter) u1))
        )
        (map-set nft-owners
            { nft-id: nft-id }
            tx-sender
        )
        (var-set listing-counter nft-id)
        (ok nft-id)
    )
)

;; Read-only functions
(define-read-only (get-listing (nft-id uint))
    (map-get? listings { nft-id: nft-id })
)

(define-read-only (get-owner (nft-id uint))
    (map-get? nft-owners { nft-id: nft-id })
)

```
