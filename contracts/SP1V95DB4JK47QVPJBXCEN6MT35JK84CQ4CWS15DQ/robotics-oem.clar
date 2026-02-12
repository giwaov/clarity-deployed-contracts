(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-COMPONENT-NOT-FOUND (err u101))
(define-constant ERR-ORDER-NOT-FOUND (err u102))

(define-map component-catalog
  { component-id: uint }
  {
    component-name: (string-ascii 50),
    component-type: (string-ascii 30),
    specifications: (string-ascii 200),
    unit-price: uint,
    stock-quantity: uint,
    manufacturer: principal
  }
)

(define-map component-orders
  { order-id: uint }
  {
    component-id: uint,
    buyer: principal,
    quantity: uint,
    total-price: uint,
    order-status: (string-ascii 20),
    ordered-at: uint,
    delivered-at: uint
  }
)

(define-data-var component-nonce uint u0)
(define-data-var order-nonce uint u0)

(define-public (register-component
  (name (string-ascii 50))
  (comp-type (string-ascii 30))
  (specs (string-ascii 200))
  (price uint)
  (quantity uint)
)
  (let ((component-id (var-get component-nonce)))
    (map-set component-catalog
      { component-id: component-id }
      {
        component-name: name,
        component-type: comp-type,
        specifications: specs,
        unit-price: price,
        stock-quantity: quantity,
        manufacturer: tx-sender
      }
    )
    (var-set component-nonce (+ component-id u1))
    (ok component-id)
  )
)

(define-public (place-order (component-id uint) (quantity uint))
  (let (
    (component (unwrap! (map-get? component-catalog { component-id: component-id }) ERR-COMPONENT-NOT-FOUND))
    (order-id (var-get order-nonce))
    (total (/ (* quantity (get unit-price component)) u100))
  )
    (map-set component-orders
      { order-id: order-id }
      {
        component-id: component-id,
        buyer: tx-sender,
        quantity: quantity,
        total-price: total,
        order-status: "pending",
        ordered-at: stacks-block-height,
        delivered-at: u0
      }
    )
    (var-set order-nonce (+ order-id u1))
    (ok order-id)
  )
)

(define-public (fulfill-order (order-id uint))
  (let ((order (unwrap! (map-get? component-orders { order-id: order-id }) ERR-ORDER-NOT-FOUND)))
    (ok (map-set component-orders
      { order-id: order-id }
      (merge order { order-status: "fulfilled", delivered-at: stacks-block-height })
    ))
  )
)

(define-read-only (get-component-info (component-id uint))
  (map-get? component-catalog { component-id: component-id })
)

(define-read-only (get-order-info (order-id uint))
  (map-get? component-orders { order-id: order-id })
)

(define-public (update-stock (component-id uint) (new-quantity uint))
  (let ((component (unwrap! (map-get? component-catalog { component-id: component-id }) ERR-COMPONENT-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get manufacturer component)) ERR-NOT-AUTHORIZED)
    (ok (map-set component-catalog
      { component-id: component-id }
      (merge component { stock-quantity: new-quantity })
    ))
  )
)

(define-public (update-price (component-id uint) (new-price uint))
  (let ((component (unwrap! (map-get? component-catalog { component-id: component-id }) ERR-COMPONENT-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get manufacturer component)) ERR-NOT-AUTHORIZED)
    (ok (map-set component-catalog
      { component-id: component-id }
      (merge component { unit-price: new-price })
    ))
  )
)
