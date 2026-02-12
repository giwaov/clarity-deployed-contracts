;; NFT Marketplace Contract
;; Full-featured NFT trading platform

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-not-authorized (err u102))
(define-constant err-already-listed (err u103))
(define-constant err-invalid-price (err u104))

(define-data-var next-listing-id uint u1)

(define-map listings
  uint
  {
    seller: principal,
    nft-id: uint,
    price: uint,
    active: bool
  }
)

(define-read-only (get-listing (listing-id uint))
  (map-get? listings listing-id)
)

(define-public (list-nft (nft-id uint) (price uint))
  (let ((listing-id (var-get next-listing-id)))
    (asserts! (> price u0) err-invalid-price)
    (map-set listings listing-id {
      seller: tx-sender,
      nft-id: nft-id,
      price: price,
      active: true
    })
    (var-set next-listing-id (+ listing-id u1))
    (ok listing-id)
  )
)

(define-public (buy-nft (listing-id uint))
  (let ((listing (unwrap! (map-get? listings listing-id) err-not-found)))
    (asserts! (get active listing) err-not-found)
    (try! (stx-transfer? (get price listing) tx-sender (get seller listing)))
    (map-set listings listing-id (merge listing { active: false }))
    (ok true)
  )
)

(define-public (cancel-listing (listing-id uint))
  (let ((listing (unwrap! (map-get? listings listing-id) err-not-found)))
    (asserts! (is-eq tx-sender (get seller listing)) err-not-authorized)
    (map-set listings listing-id (merge listing { active: false }))
    (ok true)
  )
)

(define-public (make-offer (listing-id uint) (offer-amount uint))
  (begin
    (asserts! (> offer-amount u0) err-invalid-price)
    (ok offer-amount)
  )
)
