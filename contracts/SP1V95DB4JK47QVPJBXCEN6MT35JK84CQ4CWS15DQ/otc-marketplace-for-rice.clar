(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-order-filled (err u104))

(define-map orders
  {order-id: uint}
  {
    seller: principal,
    variety: (string-ascii 64),
    quantity: uint,
    price-per-unit: uint,
    min-quantity: uint,
    status: (string-ascii 16),
    created-at: uint,
    expires-at: uint
  }
)

(define-map trades
  {trade-id: uint}
  {
    order-id: uint,
    buyer: principal,
    quantity: uint,
    price: uint,
    settled: bool,
    timestamp: uint
  }
)

(define-data-var order-nonce uint u0)
(define-data-var trade-nonce uint u0)

(define-read-only (get-order (order-id uint))
  (map-get? orders {order-id: order-id})
)

(define-read-only (get-trade (trade-id uint))
  (map-get? trades {trade-id: trade-id})
)

(define-public (create-order
  (variety (string-ascii 64))
  (quantity uint)
  (price-per-unit uint)
  (min-quantity uint)
  (duration uint)
)
  (let ((order-id (var-get order-nonce)))
    (asserts! (> quantity u0) err-invalid-params)
    (asserts! (> price-per-unit u0) err-invalid-params)
    (asserts! (<= min-quantity quantity) err-invalid-params)
    (map-set orders {order-id: order-id}
      {
        seller: tx-sender,
        variety: variety,
        quantity: quantity,
        price-per-unit: price-per-unit,
        min-quantity: min-quantity,
        status: "active",
        created-at: stacks-block-height,
        expires-at: (+ stacks-block-height duration)
      }
    )
    (var-set order-nonce (+ order-id u1))
    (ok order-id)
  )
)

(define-public (accept-order (order-id uint) (quantity uint))
  (let (
    (order (unwrap! (map-get? orders {order-id: order-id}) err-not-found))
    (trade-id (var-get trade-nonce))
  )
    (asserts! (is-eq (get status order) "active") err-order-filled)
    (asserts! (< stacks-block-height (get expires-at order)) err-invalid-params)
    (asserts! (>= quantity (get min-quantity order)) err-invalid-params)
    (asserts! (<= quantity (get quantity order)) err-invalid-params)
    (map-set trades {trade-id: trade-id}
      {
        order-id: order-id,
        buyer: tx-sender,
        quantity: quantity,
        price: (* quantity (get price-per-unit order)),
        settled: false,
        timestamp: stacks-block-height
      }
    )
    (if (is-eq quantity (get quantity order))
      (map-set orders {order-id: order-id}
        (merge order {status: "filled"})
      )
      (map-set orders {order-id: order-id}
        (merge order {quantity: (- (get quantity order) quantity)})
      )
    )
    (var-set trade-nonce (+ trade-id u1))
    (ok trade-id)
  )
)

(define-public (settle-trade (trade-id uint))
  (let ((trade (unwrap! (map-get? trades {trade-id: trade-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get buyer trade)) err-unauthorized)
    (ok (map-set trades {trade-id: trade-id}
      (merge trade {settled: true})
    ))
  )
)

(define-public (cancel-order (order-id uint))
  (let ((order (unwrap! (map-get? orders {order-id: order-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get seller order)) err-unauthorized)
    (asserts! (is-eq (get status order) "active") err-invalid-params)
    (ok (map-set orders {order-id: order-id}
      (merge order {status: "cancelled"})
    ))
  )
)
