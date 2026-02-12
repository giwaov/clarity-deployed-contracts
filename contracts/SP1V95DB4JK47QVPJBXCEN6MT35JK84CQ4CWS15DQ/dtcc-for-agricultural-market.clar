(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))

(define-map trades
  {trade-id: uint}
  {
    buyer: principal,
    seller: principal,
    product-type: (string-ascii 64),
    quantity: uint,
    price: uint,
    trade-date: uint,
    settlement-status: (string-ascii 16),
    settlement-date: (optional uint)
  }
)

(define-map positions
  {participant: principal, product-type: (string-ascii 64)}
  {long-position: uint, short-position: uint}
)

(define-map settlements
  {settlement-id: uint}
  {
    trade-ids: (list 50 uint),
    settlement-date: uint,
    status: (string-ascii 16),
    total-volume: uint
  }
)

(define-data-var trade-nonce uint u0)
(define-data-var settlement-nonce uint u0)

(define-read-only (get-trade (trade-id uint))
  (map-get? trades {trade-id: trade-id})
)

(define-read-only (get-position (participant principal) (product-type (string-ascii 64)))
  (map-get? positions {participant: participant, product-type: product-type})
)

(define-read-only (get-settlement (settlement-id uint))
  (map-get? settlements {settlement-id: settlement-id})
)

(define-public (record-trade
  (buyer principal)
  (seller principal)
  (product-type (string-ascii 64))
  (quantity uint)
  (price uint)
)
  (let ((trade-id (var-get trade-nonce)))
    (asserts! (> quantity u0) err-invalid-params)
    (asserts! (> price u0) err-invalid-params)
    (map-set trades {trade-id: trade-id}
      {
        buyer: buyer,
        seller: seller,
        product-type: product-type,
        quantity: quantity,
        price: price,
        trade-date: stacks-block-height,
        settlement-status: "pending",
        settlement-date: none
      }
    )
    (let (
      (buyer-pos (default-to {long-position: u0, short-position: u0}
        (map-get? positions {participant: buyer, product-type: product-type})))
      (seller-pos (default-to {long-position: u0, short-position: u0}
        (map-get? positions {participant: seller, product-type: product-type})))
    )
      (map-set positions {participant: buyer, product-type: product-type}
        (merge buyer-pos {long-position: (+ (get long-position buyer-pos) quantity)}))
      (map-set positions {participant: seller, product-type: product-type}
        (merge seller-pos {short-position: (+ (get short-position seller-pos) quantity)}))
    )
    (var-set trade-nonce (+ trade-id u1))
    (ok trade-id)
  )
)

(define-public (create-settlement (trade-ids (list 50 uint)))
  (let ((settlement-id (var-get settlement-nonce)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set settlements {settlement-id: settlement-id}
      {
        trade-ids: trade-ids,
        settlement-date: stacks-block-height,
        status: "pending",
        total-volume: u0
      }
    )
    (var-set settlement-nonce (+ settlement-id u1))
    (ok settlement-id)
  )
)

(define-public (mark-settled (trade-id uint))
  (let ((trade (unwrap! (map-get? trades {trade-id: trade-id}) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set trades {trade-id: trade-id}
      (merge trade {
        settlement-status: "settled",
        settlement-date: (some stacks-block-height)
      })
    ))
  )
)
