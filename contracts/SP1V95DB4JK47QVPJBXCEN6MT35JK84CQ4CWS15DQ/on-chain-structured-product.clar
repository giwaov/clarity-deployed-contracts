(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-parameters (err u102))
(define-constant err-maturity-not-reached (err u103))

(define-map products
  uint
  {
    underlying-asset: principal,
    strike-price: uint,
    maturity-block: uint,
    notional: uint,
    payout-cap: uint,
    creator: principal
  })

(define-map user-positions
  {product-id: uint, user: principal}
  {amount: uint, entry-price: uint})

(define-data-var next-product-id uint u0)

(define-read-only (get-product (product-id uint))
  (ok (map-get? products product-id)))

(define-read-only (get-position (product-id uint) (user principal))
  (ok (map-get? user-positions {product-id: product-id, user: user})))

(define-public (create-product (underlying principal) (strike uint) (maturity uint) (notional uint) (cap uint))
  (let ((product-id (var-get next-product-id)))
    (asserts! (> maturity stacks-block-height) err-invalid-parameters)
    (map-set products product-id
      {underlying-asset: underlying, strike-price: strike, maturity-block: maturity,
       notional: notional, payout-cap: cap, creator: tx-sender})
    (var-set next-product-id (+ product-id u1))
    (ok product-id)))

(define-public (purchase (product-id uint) (amount uint) (price uint))
  (begin
    (asserts! (is-some (map-get? products product-id)) err-not-found)
    (ok (map-set user-positions {product-id: product-id, user: tx-sender}
      {amount: amount, entry-price: price}))))

(define-public (settle (product-id uint) (final-price uint))
  (let ((product (unwrap! (map-get? products product-id) err-not-found)))
    (asserts! (>= stacks-block-height (get maturity-block product)) err-maturity-not-reached)
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok final-price)))
