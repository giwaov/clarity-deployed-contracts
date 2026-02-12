(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PART-NOT-FOUND (err u101))
(define-constant ERR-ORDER-NOT-FOUND (err u102))

(define-map parts-inventory
  { part-id: uint }
  {
    part-name: (string-ascii 50),
    part-category: (string-ascii 30),
    supplier: principal,
    stock-level: uint,
    reorder-threshold: uint,
    unit-cost: uint
  }
)

(define-map supply-orders
  { order-id: uint }
  {
    part-id: uint,
    buyer: principal,
    supplier: principal,
    quantity: uint,
    order-value: uint,
    order-status: (string-ascii 20),
    ordered-at: uint,
    delivered-at: uint
  }
)

(define-data-var part-nonce uint u0)
(define-data-var order-nonce uint u0)

(define-public (register-part
  (name (string-ascii 50))
  (category (string-ascii 30))
  (stock uint)
  (threshold uint)
  (cost uint)
)
  (let ((part-id (var-get part-nonce)))
    (map-set parts-inventory
      { part-id: part-id }
      {
        part-name: name,
        part-category: category,
        supplier: tx-sender,
        stock-level: stock,
        reorder-threshold: threshold,
        unit-cost: cost
      }
    )
    (var-set part-nonce (+ part-id u1))
    (ok part-id)
  )
)

(define-public (place-supply-order (part-id uint) (quantity uint))
  (let (
    (part (unwrap! (map-get? parts-inventory { part-id: part-id }) ERR-PART-NOT-FOUND))
    (order-id (var-get order-nonce))
    (total-value (/ (* quantity (get unit-cost part)) u100))
  )
    (map-set supply-orders
      { order-id: order-id }
      {
        part-id: part-id,
        buyer: tx-sender,
        supplier: (get supplier part),
        quantity: quantity,
        order-value: total-value,
        order-status: "pending",
        ordered-at: stacks-block-height,
        delivered-at: u0
      }
    )
    (var-set order-nonce (+ order-id u1))
    (ok order-id)
  )
)

(define-public (fulfill-supply-order (order-id uint))
  (let ((order (unwrap! (map-get? supply-orders { order-id: order-id }) ERR-ORDER-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get supplier order)) ERR-NOT-AUTHORIZED)
    (ok (map-set supply-orders
      { order-id: order-id }
      (merge order { order-status: "delivered", delivered-at: stacks-block-height })
    ))
  )
)

(define-public (update-stock-level (part-id uint) (new-level uint))
  (let ((part (unwrap! (map-get? parts-inventory { part-id: part-id }) ERR-PART-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get supplier part)) ERR-NOT-AUTHORIZED)
    (ok (map-set parts-inventory
      { part-id: part-id }
      (merge part { stock-level: new-level })
    ))
  )
)

(define-read-only (get-part-info (part-id uint))
  (map-get? parts-inventory { part-id: part-id })
)

(define-read-only (get-order-info (order-id uint))
  (map-get? supply-orders { order-id: order-id })
)

(define-public (update-unit-cost (part-id uint) (new-cost uint))
  (let ((part (unwrap! (map-get? parts-inventory { part-id: part-id }) ERR-PART-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get supplier part)) ERR-NOT-AUTHORIZED)
    (ok (map-set parts-inventory
      { part-id: part-id }
      (merge part { unit-cost: new-cost })
    ))
  )
)
