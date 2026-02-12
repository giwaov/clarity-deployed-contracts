---
title: "Trait auction"
draft: true
---
```
;; English Auction Contract
;; Create auctions for NFTs with ascending bids

(define-constant err-not-owner (err u100))
(define-constant err-auction-not-found (err u101))
(define-constant err-auction-ended (err u102))
(define-constant err-auction-active (err u103))
(define-constant err-bid-too-low (err u104))
(define-constant err-no-bids (err u105))

(define-data-var auction-nonce uint u0)

(define-map auctions
    uint
    {
        seller: principal,
        nft-contract: principal,
        token-id: uint,
        starting-price: uint,
        highest-bid: uint,
        highest-bidder: (optional principal),
        end-block: uint,
        finalized: bool
    }
)

;; Create an auction
(define-public (create-auction 
    (nft-contract principal) 
    (token-id uint) 
    (starting-price uint) 
    (duration uint))
    (let
        (
            (auction-id (var-get auction-nonce))
        )
        ;; In production, transfer NFT to contract
        (map-set auctions auction-id {
            seller: tx-sender,
            nft-contract: nft-contract,
            token-id: token-id,
            starting-price: starting-price,
            highest-bid: u0,
            highest-bidder: none,
            end-block: (+ block-height duration),
            finalized: false
        })
        (var-set auction-nonce (+ auction-id u1))
        (ok auction-id)
    )
)

;; Place a bid
(define-public (place-bid (auction-id uint) (bid-amount uint))
    (let
        (
            (auction (unwrap! (map-get? auctions auction-id) err-auction-not-found))
            (min-bid (if (> (get highest-bid auction) u0)
                        (+ (get highest-bid auction) u1)
                        (get starting-price auction)))
        )
        (asserts! (< block-height (get end-block auction)) err-auction-ended)
        (asserts! (>= bid-amount min-bid) err-bid-too-low)
        
        ;; Transfer bid to contract
        (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
        
        ;; Refund previous highest bidder
        (match (get highest-bidder auction)
            previous-bidder
            (try! (as-contract (stx-transfer? (get highest-bid auction) tx-sender previous-bidder)))
            true
        )
        
        ;; Update auction
        (map-set auctions auction-id (merge auction {
            highest-bid: bid-amount,
            highest-bidder: (some tx-sender)
        }))
        
        (ok true)
    )
)

;; Finalize auction and transfer NFT
(define-public (finalize-auction (auction-id uint))
    (let
        (
            (auction (unwrap! (map-get? auctions auction-id) err-auction-not-found))
        )
        (asserts! (>= block-height (get end-block auction)) err-auction-active)
        (asserts! (not (get finalized auction)) err-auction-ended)
        
        (match (get highest-bidder auction)
            winner
            (begin
                ;; Transfer payment to seller
                (try! (as-contract (stx-transfer? (get highest-bid auction) tx-sender (get seller auction))))
                ;; In production, transfer NFT to winner
                (map-set auctions auction-id (merge auction {finalized: true}))
                (ok (some winner))
            )
            (begin
                ;; No bids, mark as finalized
                (map-set auctions auction-id (merge auction {finalized: true}))
                (ok none)
            )
        )
    )
)

;; Cancel auction (only if no bids)
(define-public (cancel-auction (auction-id uint))
    (let
        (
            (auction (unwrap! (map-get? auctions auction-id) err-auction-not-found))
        )
        (asserts! (is-eq tx-sender (get seller auction)) err-not-owner)
        (asserts! (is-none (get highest-bidder auction)) err-no-bids)
        (map-set auctions auction-id (merge auction {finalized: true}))
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-auction (auction-id uint))
    (map-get? auctions auction-id)
)

(define-read-only (get-auction-count)
    (var-get auction-nonce)
)

```
