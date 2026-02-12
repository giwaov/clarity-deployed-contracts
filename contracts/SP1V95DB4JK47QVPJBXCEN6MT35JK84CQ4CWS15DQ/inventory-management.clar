(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-insufficient-inventory (err u104))

(define-map inventory-items
  {item-id: uint}
  {
    product-type: (string-ascii 64),
    owner: principal,
    quantity: uint,
    unit: (string-ascii 16),
    location: (string-ascii 128),
    batch-number: (string-ascii 64),
    created-at: uint,
    updated-at: uint
  }
)

(define-map inventory-movements
  {movement-id: uint}
  {
    item-id: uint,
    movement-type: (string-ascii 32),
    quantity: uint,
    from-location: (optional (string-ascii 128)),
    to-location: (optional (string-ascii 128)),
    timestamp: uint,
    initiated-by: principal
  }
)

(define-data-var item-nonce uint u0)
(define-data-var movement-nonce uint u0)

(define-read-only (get-inventory-item (item-id uint))
  (map-get? inventory-items {item-id: item-id})
)

(define-read-only (get-movement (movement-id uint))
  (map-get? inventory-movements {movement-id: movement-id})
)

(define-public (create-inventory-item
  (product-type (string-ascii 64))
  (quantity uint)
  (unit (string-ascii 16))
  (location (string-ascii 128))
  (batch-number (string-ascii 64))
)
  (let ((item-id (var-get item-nonce)))
    (asserts! (> quantity u0) err-invalid-params)
    (map-set inventory-items {item-id: item-id}
      {
        product-type: product-type,
        owner: tx-sender,
        quantity: quantity,
        unit: unit,
        location: location,
        batch-number: batch-number,
        created-at: stacks-block-height,
        updated-at: stacks-block-height
      }
    )
    (var-set item-nonce (+ item-id u1))
    (ok item-id)
  )
)

(define-public (adjust-inventory
  (item-id uint)
  (quantity-change int)
  (movement-type (string-ascii 32))
)
  (let (
    (item (unwrap! (map-get? inventory-items {item-id: item-id}) err-not-found))
    (movement-id (var-get movement-nonce))
    (new-quantity (if (>= quantity-change 0)
      (+ (get quantity item) (to-uint quantity-change))
      (- (get quantity item) (to-uint (- 0 quantity-change)))))
  )
    (asserts! (is-eq tx-sender (get owner item)) err-unauthorized)
    (if (< quantity-change 0)
      (asserts! (>= (get quantity item) (to-uint (- 0 quantity-change))) err-insufficient-inventory)
      true
    )
    (map-set inventory-items {item-id: item-id}
      (merge item {
        quantity: new-quantity,
        updated-at: stacks-block-height
      })
    )
    (map-set inventory-movements {movement-id: movement-id}
      {
        item-id: item-id,
        movement-type: movement-type,
        quantity: (if (>= quantity-change 0) (to-uint quantity-change) (to-uint (- 0 quantity-change))),
        from-location: (if (< quantity-change 0) (some (get location item)) none),
        to-location: (if (>= quantity-change 0) (some (get location item)) none),
        timestamp: stacks-block-height,
        initiated-by: tx-sender
      }
    )
    (var-set movement-nonce (+ movement-id u1))
    (ok movement-id)
  )
)

(define-public (transfer-inventory
  (item-id uint)
  (quantity uint)
  (new-owner principal)
  (new-location (string-ascii 128))
)
  (let (
    (item (unwrap! (map-get? inventory-items {item-id: item-id}) err-not-found))
    (movement-id (var-get movement-nonce))
  )
    (asserts! (is-eq tx-sender (get owner item)) err-unauthorized)
    (asserts! (<= quantity (get quantity item)) err-insufficient-inventory)
    (if (is-eq quantity (get quantity item))
      (map-set inventory-items {item-id: item-id}
        (merge item {
          owner: new-owner,
          location: new-location,
          updated-at: stacks-block-height
        })
      )
      (begin
        (map-set inventory-items {item-id: item-id}
          (merge item {
            quantity: (- (get quantity item) quantity),
            updated-at: stacks-block-height
          })
        )
        (map-set inventory-items {item-id: (var-get item-nonce)}
          {
            product-type: (get product-type item),
            owner: new-owner,
            quantity: quantity,
            unit: (get unit item),
            location: new-location,
            batch-number: (get batch-number item),
            created-at: stacks-block-height,
            updated-at: stacks-block-height
          }
        )
        (var-set item-nonce (+ (var-get item-nonce) u1))
      )
    )
    (map-set inventory-movements {movement-id: movement-id}
      {
        item-id: item-id,
        movement-type: "transfer",
        quantity: quantity,
        from-location: (some (get location item)),
        to-location: (some new-location),
        timestamp: stacks-block-height,
        initiated-by: tx-sender
      }
    )
    (var-set movement-nonce (+ movement-id u1))
    (ok movement-id)
  )
)
