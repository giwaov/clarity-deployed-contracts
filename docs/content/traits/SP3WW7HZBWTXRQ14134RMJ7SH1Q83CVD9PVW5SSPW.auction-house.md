---
title: "Trait auction-house"
draft: true
---
```
;; Auction House Contract
;; English and Dutch auction mechanisms

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-auction-ended (err u102))
(define-constant err-bid-too-low (err u103))

(define-data-var next-auction-id uint u1)

(define-map auctions
  uint
  {
    seller: principal,
    nft-id: uint,
    starting-price: uint,
    highest-bid: uint,
    highest-bidder: (optional principal),
    end-block: uint,
    settled: bool
  }
)

(define-read-only (get-auction (auction-id uint))
  (map-get? auctions auction-id)
)

(define-public (create-auction (nft-id uint) (starting-price uint) (duration uint))
  (let ((auction-id (var-get next-auction-id)))
    (map-set auctions auction-id {
      seller: tx-sender,
      nft-id: nft-id,
      starting-price: starting-price,
      highest-bid: starting-price,
      highest-bidder: none,
      end-block: (+ block-height duration),
      settled: false
    })
    (var-set next-auction-id (+ auction-id u1))
    (ok auction-id)
  )
)

(define-public (place-bid (auction-id uint) (bid-amount uint))
  (let ((auction (unwrap! (map-get? auctions auction-id) err-not-found)))
    (asserts! (< block-height (get end-block auction)) err-auction-ended)
    (asserts! (> bid-amount (get highest-bid auction)) err-bid-too-low)
    (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
    (map-set auctions auction-id (merge auction {
      highest-bid: bid-amount,
      highest-bidder: (some tx-sender)
    }))
    (ok true)
  )
)

(define-public (settle-auction (auction-id uint))
  (let ((auction (unwrap! (map-get? auctions auction-id) err-not-found)))
    (asserts! (>= block-height (get end-block auction)) (err u104))
    (asserts! (not (get settled auction)) (err u105))
    (map-set auctions auction-id (merge auction { settled: true }))
    (ok true)
  )
)

```
