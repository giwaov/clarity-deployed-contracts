(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-invalid-product (err u118))

(define-data-var product-nonce uint u0)

(define-map finance-products
  uint
  {
    provider: principal,
    borrower: principal,
    product-type: (string-ascii 30),
    amount: uint,
    term-rate: uint,
    specific-parameters: (string-ascii 100),
    outstanding: uint,
    active: bool,
    issue-block: uint,
    maturity-block: uint
  }
)

(define-map product-payments
  {product-id: uint, payment-id: uint}
  {
    amount: uint,
    block: uint,
    fee-portion: uint
  }
)

(define-map payment-counter uint uint)
(define-map provider-products principal (list 50 uint))
(define-map borrower-products principal (list 30 uint))

(define-public (create-product (borrower principal) (product-type (string-ascii 30)) (amount uint) 
                                (rate uint) (parameters (string-ascii 100)) (maturity uint))
  (let
    (
      (product-id (+ (var-get product-nonce) u1))
    )
    (asserts! (> amount u0) err-invalid-amount)
    (map-set finance-products product-id {
      provider: tx-sender,
      borrower: borrower,
      product-type: product-type,
      amount: amount,
      term-rate: rate,
      specific-parameters: parameters,
      outstanding: amount,
      active: true,
      issue-block: stacks-block-height,
      maturity-block: maturity
    })
    (map-set payment-counter product-id u0)
    (map-set provider-products tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? provider-products tx-sender)) product-id) u50)))
    (map-set borrower-products borrower
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? borrower-products borrower)) product-id) u30)))
    (var-set product-nonce product-id)
    (ok product-id)
  )
)

(define-public (disburse-product (product-id uint))
  (let
    (
      (product (unwrap! (map-get? finance-products product-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get provider product)) err-unauthorized)
    (asserts! (get active product) err-invalid-product)
    (try! (stx-transfer? (get amount product) tx-sender (get borrower product)))
    (ok true)
  )
)

(define-public (make-payment (product-id uint) (amount uint))
  (let
    (
      (product (unwrap! (map-get? finance-products product-id) err-not-found))
      (fees (calculate-fees product-id))
      (new-outstanding (if (>= amount (get outstanding product)) 
                          u0 
                          (- (get outstanding product) amount)))
      (pid (+ (default-to u0 (map-get? payment-counter product-id)) u1))
    )
    (asserts! (is-eq tx-sender (get borrower product)) err-unauthorized)
    (asserts! (get active product) err-invalid-product)
    (try! (stx-transfer? amount tx-sender (get provider product)))
    (map-set product-payments {product-id: product-id, payment-id: pid} {
      amount: amount,
      block: stacks-block-height,
      fee-portion: fees
    })
    (map-set payment-counter product-id pid)
    (map-set finance-products product-id (merge product {
      outstanding: new-outstanding,
      active: (> new-outstanding u0)
    }))
    (ok true)
  )
)

(define-public (restructure-product (product-id uint) (new-rate uint) (new-maturity uint))
  (let
    (
      (product (unwrap! (map-get? finance-products product-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get provider product)) err-unauthorized)
    (map-set finance-products product-id (merge product {
      term-rate: new-rate,
      maturity-block: new-maturity
    }))
    (ok true)
  )
)

(define-public (settle-product (product-id uint))
  (let
    (
      (product (unwrap! (map-get? finance-products product-id) err-not-found))
      (total-due (calculate-total-due product-id))
    )
    (asserts! (is-eq tx-sender (get borrower product)) err-unauthorized)
    (asserts! (get active product) err-invalid-product)
    (try! (stx-transfer? total-due tx-sender (get provider product)))
    (map-set finance-products product-id (merge product {outstanding: u0, active: false}))
    (ok true)
  )
)

(define-read-only (get-product (product-id uint))
  (ok (map-get? finance-products product-id))
)

(define-read-only (get-payment (product-id uint) (payment-id uint))
  (ok (map-get? product-payments {product-id: product-id, payment-id: payment-id}))
)

(define-read-only (get-borrower-products (borrower principal))
  (ok (map-get? borrower-products borrower))
)

(define-read-only (calculate-fees (product-id uint))
  (let
    (
      (product (unwrap-panic (map-get? finance-products product-id)))
      (outstanding (get outstanding product))
      (rate (get term-rate product))
      (elapsed (- stacks-block-height (get issue-block product)))
    )
    (/ (* outstanding (* rate elapsed)) u10000000)
  )
)

(define-read-only (calculate-total-due (product-id uint))
  (let
    (
      (product (unwrap-panic (map-get? finance-products product-id)))
      (outstanding (get outstanding product))
      (fees (calculate-fees product-id))
    )
    (+ outstanding fees)
  )
)

(define-read-only (get-product-status (product-id uint))
  (let
    (
      (product (unwrap-panic (map-get? finance-products product-id)))
    )
    (ok {
      active: (get active product),
      outstanding: (get outstanding product),
      overdue: (> stacks-block-height (get maturity-block product)),
      product-type: (get product-type product)
    })
  )
)
