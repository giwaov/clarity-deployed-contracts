---
title: "Trait stacksmint-marketplace"
draft: true
---
```
;; StacksMint Marketplace Contract
;; Buy/sell NFTs with creator fees on each sale
;; Creator Fee: 0.01 STX per sale

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-LISTED (err u102))
(define-constant ERR-NOT-TOKEN-OWNER (err u103))
(define-constant ERR-INVALID-PRICE (err u104))
(define-constant ERR-LISTING-NOT-FOUND (err u105))
(define-constant ERR-WRONG-PRICE (err u106))
(define-constant ERR-CANNOT-BUY-OWN (err u107))
(define-constant ERR-TRANSFER-FAILED (err u108))
(define-constant ERR-INSUFFICIENT-FUNDS (err u109))
(define-constant CREATOR-FEE u10000) ;; 0.01 STX in microSTX

;; Data Variables
(define-data-var total-listings uint u0)
(define-data-var total-sales uint u0)
(define-data-var total-volume uint u0)

;; Data Maps
(define-map listings uint {
  seller: principal,
  nft-contract: principal,
  token-id: uint,
  price: uint,
  listed-at: uint,
  is-active: bool
})

(define-map nft-listing { nft-contract: principal, token-id: uint } uint) ;; maps to listing-id

;; Read-only functions

;; Get creator fee
(define-read-only (get-creator-fee)
  CREATOR-FEE
)

;; Get total listings count
(define-read-only (get-total-listings)
  (var-get total-listings)
)

;; Get total sales count
(define-read-only (get-total-sales)
  (var-get total-sales)
)

;; Get total trading volume
(define-read-only (get-total-volume)
  (var-get total-volume)
)

;; Get listing by ID
(define-read-only (get-listing (listing-id uint))
  (map-get? listings listing-id)
)

;; Get listing ID for NFT
(define-read-only (get-nft-listing-id (nft-contract principal) (token-id uint))
  (map-get? nft-listing { nft-contract: nft-contract, token-id: token-id })
)

;; Get listing for NFT
(define-read-only (get-nft-listing (nft-contract principal) (token-id uint))
  (match (get-nft-listing-id nft-contract token-id)
    listing-id (map-get? listings listing-id)
    none
  )
)

;; Check if NFT is listed
(define-read-only (is-listed (nft-contract principal) (token-id uint))
  (match (get-nft-listing nft-contract token-id)
    listing (get is-active listing)
    false
  )
)

;; Get listing price
(define-read-only (get-listing-price (nft-contract principal) (token-id uint))
  (match (get-nft-listing nft-contract token-id)
    listing (if (get is-active listing)
      (some (get price listing))
      none
    )
    none
  )
)

;; Public functions

;; List NFT for sale
(define-public (list-nft (nft-contract principal) (token-id uint) (price uint))
  (let
    (
      (listing-id (+ (var-get total-listings) u1))
    )
    ;; Validate price
    (asserts! (> price u0) ERR-INVALID-PRICE)
    ;; Check not already listed
    (asserts! (not (is-listed nft-contract token-id)) ERR-ALREADY-LISTED)
    ;; Create listing
    (map-set listings listing-id {
      seller: tx-sender,
      nft-contract: nft-contract,
      token-id: token-id,
      price: price,
      listed-at: block-height,
      is-active: true
    })
    ;; Map NFT to listing
    (map-set nft-listing { nft-contract: nft-contract, token-id: token-id } listing-id)
    ;; Update total listings
    (var-set total-listings listing-id)
    (ok listing-id)
  )
)

;; Update listing price
(define-public (update-listing (nft-contract principal) (token-id uint) (new-price uint))
  (match (get-nft-listing-id nft-contract token-id)
    listing-id (match (map-get? listings listing-id)
      listing (begin
        (asserts! (is-eq tx-sender (get seller listing)) ERR-NOT-AUTHORIZED)
        (asserts! (get is-active listing) ERR-LISTING-NOT-FOUND)
        (asserts! (> new-price u0) ERR-INVALID-PRICE)
        (map-set listings listing-id 
          (merge listing { price: new-price })
        )
        (ok true)
      )
      ERR-LISTING-NOT-FOUND
    )
    ERR-LISTING-NOT-FOUND
  )
)

;; Cancel listing
(define-public (cancel-listing (nft-contract principal) (token-id uint))
  (match (get-nft-listing-id nft-contract token-id)
    listing-id (match (map-get? listings listing-id)
      listing (begin
        (asserts! (is-eq tx-sender (get seller listing)) ERR-NOT-AUTHORIZED)
        (asserts! (get is-active listing) ERR-LISTING-NOT-FOUND)
        (map-set listings listing-id 
          (merge listing { is-active: false })
        )
        (map-delete nft-listing { nft-contract: nft-contract, token-id: token-id })
        (ok true)
      )
      ERR-LISTING-NOT-FOUND
    )
    ERR-LISTING-NOT-FOUND
  )
)

;; Buy listed NFT (pays seller + creator fee)
(define-public (buy-nft (nft-contract principal) (token-id uint) (expected-price uint))
  (match (get-nft-listing-id nft-contract token-id)
    listing-id (match (map-get? listings listing-id)
      listing (let
        (
          (seller (get seller listing))
          (price (get price listing))
          (total-cost (+ price CREATOR-FEE))
        )
        ;; Validations
        (asserts! (get is-active listing) ERR-LISTING-NOT-FOUND)
        (asserts! (is-eq price expected-price) ERR-WRONG-PRICE)
        (asserts! (not (is-eq tx-sender seller)) ERR-CANNOT-BUY-OWN)
        ;; Pay seller
        (try! (stx-transfer? price tx-sender seller))
        ;; Pay creator fee
        (try! (stx-transfer? CREATOR-FEE tx-sender CONTRACT-OWNER))
        ;; Update listing to inactive
        (map-set listings listing-id 
          (merge listing { is-active: false })
        )
        ;; Remove NFT listing mapping
        (map-delete nft-listing { nft-contract: nft-contract, token-id: token-id })
        ;; Update stats
        (var-set total-sales (+ (var-get total-sales) u1))
        (var-set total-volume (+ (var-get total-volume) price))
        (ok { listing-id: listing-id, price: price, fee: CREATOR-FEE })
      )
      ERR-LISTING-NOT-FOUND
    )
    ERR-LISTING-NOT-FOUND
  )
)

;; Buy NFT with integrated transfer (for StacksMint NFTs)
;; Note: This requires the seller to have approved the marketplace contract
(define-public (buy-stacksmint-nft (token-id uint) (expected-price uint))
  (let
    (
      (nft-contract (as-contract tx-sender))
    )
    (buy-nft nft-contract token-id expected-price)
  )
)

;; Admin function to pause a listing (contract owner only - for emergencies)
(define-public (admin-pause-listing (listing-id uint))
  (match (map-get? listings listing-id)
    listing (begin
      (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
      (map-set listings listing-id 
        (merge listing { is-active: false })
      )
      (map-delete nft-listing { 
        nft-contract: (get nft-contract listing), 
        token-id: (get token-id listing) 
      })
      (ok true)
    )
    ERR-LISTING-NOT-FOUND
  )
)

```
