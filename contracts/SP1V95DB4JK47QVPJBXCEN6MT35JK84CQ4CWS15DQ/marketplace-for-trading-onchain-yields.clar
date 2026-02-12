(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-amount (err u102))
(define-constant err-already-exists (err u103))

(define-map yield-tokens
  uint
  {
    protocol: (string-ascii 64),
    token-address: principal,
    apy: uint,
    maturity-block: uint,
    total-supply: uint,
    owner: principal
  })

(define-map listings
  uint
  {
    yield-token-id: uint,
    seller: principal,
    amount: uint,
    price-per-token: uint,
    active: bool
  })

(define-data-var next-token-id uint u0)
(define-data-var next-listing-id uint u0)

(define-read-only (get-yield-token (token-id uint))
  (ok (map-get? yield-tokens token-id)))

(define-read-only (get-listing (listing-id uint))
  (ok (map-get? listings listing-id)))

(define-public (register-yield-token (protocol (string-ascii 64)) (token principal) (apy uint) (maturity uint) (supply uint))
  (let ((token-id (var-get next-token-id)))
    (map-set yield-tokens token-id
      {protocol: protocol, token-address: token, apy: apy, maturity-block: maturity,
       total-supply: supply, owner: tx-sender})
    (var-set next-token-id (+ token-id u1))
    (ok token-id)))

(define-public (create-listing (token-id uint) (amount uint) (price uint))
  (let ((listing-id (var-get next-listing-id)))
    (asserts! (is-some (map-get? yield-tokens token-id)) err-not-found)
    (asserts! (> amount u0) err-invalid-amount)
    (map-set listings listing-id
      {yield-token-id: token-id, seller: tx-sender, amount: amount,
       price-per-token: price, active: true})
    (var-set next-listing-id (+ listing-id u1))
    (ok listing-id)))

(define-public (purchase-yield (listing-id uint) (amount uint))
  (let ((listing (unwrap! (map-get? listings listing-id) err-not-found)))
    (asserts! (get active listing) err-not-found)
    (asserts! (>= (get amount listing) amount) err-invalid-amount)
    (map-set listings listing-id (merge listing {amount: (- (get amount listing) amount)}))
    (ok true)))

(define-public (cancel-listing (listing-id uint))
  (let ((listing (unwrap! (map-get? listings listing-id) err-not-found)))
    (asserts! (is-eq tx-sender (get seller listing)) err-owner-only)
    (ok (map-set listings listing-id (merge listing {active: false})))))
