---
title: "Trait marketplace"
draft: true
---
```

;; Simple NFT Marketplace
;; List and buy NFTs with STX

(define-constant err-not-owner (err u100))
(define-constant err-listing-not-found (err u101))
(define-constant err-already-listed (err u102))
(define-constant err-nft-not-owned (err u103))

(define-data-var listing-nonce uint u0)

(define-map listings
    uint
    {
        nft-contract: principal,
        token-id: uint,
        seller: principal,
        price: uint,
        active: bool
    }
)

;; Create a listing
(define-public (list-nft (nft-contract principal) (token-id uint) (price uint))
    (let
        (
            (listing-id (var-get listing-nonce))
        )
        ;; In production, verify NFT ownership via contract call
        (map-set listings listing-id {
            nft-contract: nft-contract,
            token-id: token-id,
            seller: tx-sender,
            price: price,
            active: true
        })
        (var-set listing-nonce (+ listing-id u1))
        (ok listing-id)
    )
)

;; Cancel a listing
(define-public (cancel-listing (listing-id uint))
    (let
        (
            (listing (unwrap! (map-get? listings listing-id) err-listing-not-found))
        )
        (asserts! (is-eq tx-sender (get seller listing)) err-not-owner)
        (asserts! (get active listing) err-listing-not-found)
        (map-set listings listing-id (merge listing {active: false}))
        (ok true)
    )
)

;; Buy an NFT
(define-public (buy-nft (listing-id uint))
    (let
        (
            (listing (unwrap! (map-get? listings listing-id) err-listing-not-found))
        )
        (asserts! (get active listing) err-listing-not-found)
        
        ;; Transfer STX to seller
        (try! (stx-transfer? (get price listing) tx-sender (get seller listing)))
        
        ;; Mark listing as inactive
        (map-set listings listing-id (merge listing {active: false}))
        
        ;; In production, transfer NFT via contract-call
        ;; (try! (contract-call? (get nft-contract listing) transfer (get token-id listing) (get seller listing) tx-sender))
        
        (ok true)
    )
)

;; Update listing price
(define-public (update-price (listing-id uint) (new-price uint))
    (let
        (
            (listing (unwrap! (map-get? listings listing-id) err-listing-not-found))
        )
        (asserts! (is-eq tx-sender (get seller listing)) err-not-owner)
        (asserts! (get active listing) err-listing-not-found)
        (map-set listings listing-id (merge listing {price: new-price}))
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-listing (listing-id uint))
    (map-get? listings listing-id)
)

(define-read-only (get-listing-count)
    (var-get listing-nonce)
)

```
