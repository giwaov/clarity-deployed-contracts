---
title: "Trait stacks-LedgerLink"
draft: true
---
```
;; TradeMint - Decentralized Trading Platform
;; A platform for trading digital assets with secure escrow capabilities

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-listing-not-found (err u101))
(define-constant err-invalid-status (err u102))
(define-constant err-insufficient-balance (err u103))
(define-constant err-no-active-offer (err u104))
(define-constant err-listing-expired (err u105))
(define-constant err-invalid-amount (err u106))
(define-constant err-offer-not-found (err u107))
(define-constant err-listing-closed (err u108))
(define-constant err-already-has-offer (err u109))

;; Data Variables
(define-map listings
    uint
    {
        seller: principal,
        asset: (string-ascii 32),
        price: uint,
        status: (string-ascii 10),
        expiry: uint,
        created-at: uint
    }
)

(define-map offers
    {listing-id: uint, buyer: principal}
    {
        amount: uint,
        status: (string-ascii 10),
        created-at: uint
    }
)

(define-data-var listing-nonce uint u0)

;; Events
(define-data-var event-id uint u0)

(define-private (emit-event (event-type (string-ascii 20)) (listing-id uint) (principal-data (optional principal)))
    (begin
        (var-set event-id (+ (var-get event-id) u1))
        (print {event-id: (var-get event-id), event-type: event-type, listing-id: listing-id, principal: principal-data})
    )
)

;; Private Functions
(define-private (increment-nonce)
    (begin
        (var-set listing-nonce (+ (var-get listing-nonce) u1))
        (ok (var-get listing-nonce))
    )
)


(define-private (is-listing-active (listing {seller: principal, asset: (string-ascii 32), price: uint, status: (string-ascii 10), expiry: uint, created-at: uint}))
    (and
        (is-eq (get status listing) "active")
        (< stacks-block-time (get expiry listing))
    )
)


;; Public Functions  
(define-public (create-listing (asset (string-ascii 32)) (price uint) (expiry uint))
    (let
        (
            (current-block stacks-block-time)
            (new-id (var-get listing-nonce))
        )
        ;; Increment the nonce first
        (var-set listing-nonce (+ new-id u1))
        
        ;; Validate parameters
        (asserts! (> expiry current-block) (err err-invalid-status))
        (asserts! (> price u0) (err err-invalid-amount))
        
        ;; Create the listing
        (map-insert listings
            new-id
            {
                seller: tx-sender,
                asset: asset,
                price: price,
                status: "active",
                expiry: expiry,
                created-at: current-block
            }
        )
        (emit-event "listing-created" new-id none)
        (ok new-id)
    )
)


(define-public (cancel-listing (listing-id uint))
    (let
        (
            (listing (unwrap! (map-get? listings listing-id) (err err-listing-not-found)))
        )
        (asserts! (is-eq (get seller listing) tx-sender) (err err-not-authorized))
        (asserts! (is-eq (get status listing) "active") (err err-invalid-status))
        
        (map-set listings listing-id
            (merge listing {status: "cancelled"})
        )
        (emit-event "listing-cancelled" listing-id none)
        (ok true)
    )
)



;; Admin function to recover expired listings and refund related offers
(define-public (cleanup-expired-listing (listing-id uint))
    (let
        (
            (listing (unwrap! (map-get? listings listing-id) (err err-listing-not-found)))
        )
        ;; Verify listing is expired and still active
        (asserts! (and (>= stacks-block-time (get expiry listing))
                      (is-eq (get status listing) "active"))
                 (err err-invalid-status))
        
        ;; Mark listing as expired
        (map-set listings
            listing-id
            (merge listing {status: "expired"})
        )
        
        (emit-event "listing-expired" listing-id none)
        (ok true)
    )
)

;; Read-only functions
(define-read-only (get-listing (listing-id uint))
    (map-get? listings listing-id)
)

(define-read-only (get-offer (listing-id uint) (buyer principal))
    (map-get? offers {listing-id: listing-id, buyer: buyer})
)

(define-read-only (get-listing-count)
    (var-get listing-nonce)
)

(define-read-only (is-expired (listing-id uint))
    (match (map-get? listings listing-id)
        listing (>= stacks-block-time (get expiry listing))
        false
    )
)
```
