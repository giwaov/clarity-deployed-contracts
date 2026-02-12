---
title: "Trait Bet-Dex"
draft: true
---
```
;; title: Bet-Dex
;; version:
;; summary:
;; description:
;; Decentralized Marketplace Smart Contract
;; A trustless marketplace for digital goods with escrow and dispute resolution

;; Error constants
(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_LISTING_NOT_FOUND (err u101))
(define-constant ERR_INVALID_PRICE (err u102))
(define-constant ERR_INVALID_DESCRIPTION (err u103))
(define-constant ERR_LISTING_EXPIRED (err u104))
(define-constant ERR_INSUFFICIENT_FUNDS (err u105))
(define-constant ERR_CANNOT_BUY_OWN_LISTING (err u106))
(define-constant ERR_LISTING_NOT_ACTIVE (err u107))
(define-constant ERR_PURCHASE_NOT_FOUND (err u108))
(define-constant ERR_ALREADY_CONFIRMED (err u109))
(define-constant ERR_CONFIRMATION_PERIOD_EXPIRED (err u110))
(define-constant ERR_DISPUTE_ALREADY_EXISTS (err u111))
(define-constant ERR_DISPUTE_NOT_FOUND (err u112))
(define-constant ERR_INVALID_ARBITRATOR (err u113))
(define-constant ERR_DISPUTE_ALREADY_RESOLVED (err u114))

;; Contract data variables
(define-data-var listing-counter uint u0)
(define-data-var purchase-counter uint u0)
(define-data-var dispute-counter uint u0)
(define-data-var marketplace-admin principal tx-sender)
(define-data-var marketplace-fee-percentage uint u250) ;; 2.5% fee (250 basis points)
(define-data-var confirmation-period uint u259200) ;; 3 days in seconds
(define-data-var dispute-period uint u604800) ;; 7 days in seconds

;; Listing status enum values
(define-constant STATUS_ACTIVE u1)
(define-constant STATUS_PURCHASED u2)
(define-constant STATUS_CANCELLED u3)
(define-constant STATUS_COMPLETED u4)

;; Purchase status enum values
(define-constant PURCHASE_PENDING u1)
(define-constant PURCHASE_CONFIRMED u2)
(define-constant PURCHASE_DISPUTED u3)
(define-constant PURCHASE_REFUNDED u4)

;; Dispute status enum values
(define-constant DISPUTE_OPEN u1)
(define-constant DISPUTE_RESOLVED_BUYER u2)
(define-constant DISPUTE_RESOLVED_SELLER u3)

;; Data structures
(define-map listings
  { listing-id: uint }
  {
    seller: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    price: uint,
    category: (string-ascii 32),
    digital-asset-hash: (string-ascii 64),
    status: uint,
    created-at: uint,
    expires-at: uint
  }
)

(define-map purchases
  { purchase-id: uint }
  {
    listing-id: uint,
    buyer: principal,
    seller: principal,
    amount: uint,
    status: uint,
    purchased-at: uint,
    confirmation-deadline: uint
  }
)

(define-map disputes
  { dispute-id: uint }
  {
    purchase-id: uint,
    buyer: principal,
    seller: principal,
    arbitrator: principal,
    reason: (string-ascii 256),
    status: uint,
    created-at: uint,
    resolved-at: (optional uint)
  }
)

(define-map escrow-funds
  { purchase-id: uint }
  { amount: uint }
)

(define-map user-ratings
  { user: principal }
  {
    total-score: uint,
    total-ratings: uint,
    average-rating: uint
  }
)

(define-map arbitrators
  { arbitrator: principal }
  { is-active: bool }
)

;; Helper functions
(define-private (get-next-listing-id)
  (begin
    (var-set listing-counter (+ (var-get listing-counter) u1))
    (var-get listing-counter)
  )
)

(define-private (get-next-purchase-id)
  (begin
    (var-set purchase-counter (+ (var-get purchase-counter) u1))
    (var-get purchase-counter)
  )
)

(define-private (get-next-dispute-id)
  (begin
    (var-set dispute-counter (+ (var-get dispute-counter) u1))
    (var-get dispute-counter)
  )
)

(define-private (calculate-marketplace-fee (amount uint))
  (/ (* amount (var-get marketplace-fee-percentage)) u10000)
)

(define-private (calculate-seller-amount (amount uint))
  (- amount (calculate-marketplace-fee amount))
)



;; Read-only functions
(define-read-only (get-listing (listing-id uint))
  (map-get? listings { listing-id: listing-id })
)

(define-read-only (get-purchase (purchase-id uint))
  (map-get? purchases { purchase-id: purchase-id })
)

(define-read-only (get-dispute (dispute-id uint))
  (map-get? disputes { dispute-id: dispute-id })
)

(define-read-only (get-escrow-amount (purchase-id uint))
  (map-get? escrow-funds { purchase-id: purchase-id })
)

(define-read-only (get-marketplace-stats)
  (ok {
    total-listings: (var-get listing-counter),
    total-purchases: (var-get purchase-counter),
    total-disputes: (var-get dispute-counter),
    marketplace-fee: (var-get marketplace-fee-percentage)
  })
)

(define-read-only (get-user-rating (user principal))
  (default-to { total-score: u0, total-ratings: u0, average-rating: u0 }
    (map-get? user-ratings { user: user })
  )
)


```
