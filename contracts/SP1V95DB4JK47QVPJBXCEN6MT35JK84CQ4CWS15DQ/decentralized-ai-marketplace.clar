(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-listing-inactive (err u105))
(define-constant err-already-purchased (err u106))

(define-data-var listing-nonce uint u0)

(define-map listings
  uint
  {
    seller: principal,
    ai-service-type: (string-ascii 50),
    description-hash: (buff 32),
    price: uint,
    license-type: (string-ascii 20),
    active: bool,
    total-sales: uint,
    rating-sum: uint,
    rating-count: uint
  }
)

(define-map purchases
  {buyer: principal, listing-id: uint}
  {
    purchase-block: uint,
    access-granted: bool,
    rated: bool
  }
)

(define-map seller-listings principal (list 100 uint))
(define-map buyer-purchases principal (list 100 uint))

(define-public (create-listing (ai-service-type (string-ascii 50)) (description-hash (buff 32)) (price uint) (license-type (string-ascii 20)))
  (let
    (
      (listing-id (+ (var-get listing-nonce) u1))
    )
    (asserts! (> price u0) err-invalid-amount)
    (map-set listings listing-id
      {
        seller: tx-sender,
        ai-service-type: ai-service-type,
        description-hash: description-hash,
        price: price,
        license-type: license-type,
        active: true,
        total-sales: u0,
        rating-sum: u0,
        rating-count: u0
      }
    )
    (map-set seller-listings tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? seller-listings tx-sender)) listing-id) u100)))
    (var-set listing-nonce listing-id)
    (ok listing-id)
  )
)

(define-public (purchase-listing (listing-id uint))
  (let
    (
      (listing (unwrap! (map-get? listings listing-id) err-not-found))
    )
    (asserts! (get active listing) err-listing-inactive)
    (asserts! (is-none (map-get? purchases {buyer: tx-sender, listing-id: listing-id})) err-already-purchased)
    (try! (stx-transfer? (get price listing) tx-sender (get seller listing)))
    (map-set purchases {buyer: tx-sender, listing-id: listing-id}
      {
        purchase-block: stacks-block-height,
        access-granted: true,
        rated: false
      }
    )
    (map-set listings listing-id (merge listing {
      total-sales: (+ (get total-sales listing) u1)
    }))
    (map-set buyer-purchases tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? buyer-purchases tx-sender)) listing-id) u100)))
    (ok true)
  )
)

(define-public (rate-listing (listing-id uint) (rating uint))
  (let
    (
      (listing (unwrap! (map-get? listings listing-id) err-not-found))
      (purchase (unwrap! (map-get? purchases {buyer: tx-sender, listing-id: listing-id}) err-not-found))
    )
    (asserts! (<= rating u100) err-invalid-amount)
    (asserts! (not (get rated purchase)) err-already-exists)
    (map-set purchases {buyer: tx-sender, listing-id: listing-id} (merge purchase {rated: true}))
    (map-set listings listing-id (merge listing {
      rating-sum: (+ (get rating-sum listing) rating),
      rating-count: (+ (get rating-count listing) u1)
    }))
    (ok true)
  )
)

(define-public (update-listing-status (listing-id uint) (active bool))
  (let
    (
      (listing (unwrap! (map-get? listings listing-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get seller listing)) err-unauthorized)
    (map-set listings listing-id (merge listing {active: active}))
    (ok true)
  )
)

(define-public (update-listing-price (listing-id uint) (new-price uint))
  (let
    (
      (listing (unwrap! (map-get? listings listing-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get seller listing)) err-unauthorized)
    (asserts! (> new-price u0) err-invalid-amount)
    (map-set listings listing-id (merge listing {price: new-price}))
    (ok true)
  )
)

(define-read-only (get-listing (listing-id uint))
  (ok (map-get? listings listing-id))
)

(define-read-only (get-purchase (buyer principal) (listing-id uint))
  (ok (map-get? purchases {buyer: buyer, listing-id: listing-id}))
)

(define-read-only (get-seller-listings (seller principal))
  (ok (map-get? seller-listings seller))
)

(define-read-only (get-buyer-purchases (buyer principal))
  (ok (map-get? buyer-purchases buyer))
)

(define-read-only (get-average-rating (listing-id uint))
  (let
    (
      (listing (unwrap! (map-get? listings listing-id) err-not-found))
      (rating-count (get rating-count listing))
    )
    (ok (if (> rating-count u0)
      (/ (get rating-sum listing) rating-count)
      u0))
  )
)
