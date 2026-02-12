(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))

(define-map suppliers
  {supplier-id: principal}
  {
    name: (string-ascii 128),
    product-type: (string-ascii 64),
    total-supplied: uint,
    verified: bool,
    active: bool
  }
)

(define-map aggregation-batches
  {batch-id: uint}
  {
    product-type: (string-ascii 64),
    total-quantity: uint,
    num-suppliers: uint,
    aggregator: principal,
    status: (string-ascii 32),
    created-at: uint,
    target-quantity: uint
  }
)

(define-map batch-contributions
  {batch-id: uint, supplier: principal}
  {quantity: uint, timestamp: uint}
)

(define-data-var batch-nonce uint u0)

(define-read-only (get-supplier (supplier-id principal))
  (map-get? suppliers {supplier-id: supplier-id})
)

(define-read-only (get-batch (batch-id uint))
  (map-get? aggregation-batches {batch-id: batch-id})
)

(define-read-only (get-contribution (batch-id uint) (supplier principal))
  (map-get? batch-contributions {batch-id: batch-id, supplier: supplier})
)

(define-public (register-supplier
  (supplier-id principal)
  (name (string-ascii 128))
  (product-type (string-ascii 64))
)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set suppliers {supplier-id: supplier-id}
      {
        name: name,
        product-type: product-type,
        total-supplied: u0,
        verified: true,
        active: true
      }
    ))
  )
)

(define-public (create-batch
  (product-type (string-ascii 64))
  (target-quantity uint)
)
  (let ((batch-id (var-get batch-nonce)))
    (asserts! (> target-quantity u0) err-invalid-params)
    (map-set aggregation-batches {batch-id: batch-id}
      {
        product-type: product-type,
        total-quantity: u0,
        num-suppliers: u0,
        aggregator: tx-sender,
        status: "open",
        created-at: stacks-block-height,
        target-quantity: target-quantity
      }
    )
    (var-set batch-nonce (+ batch-id u1))
    (ok batch-id)
  )
)

(define-public (contribute-to-batch
  (batch-id uint)
  (quantity uint)
)
  (let (
    (batch (unwrap! (map-get? aggregation-batches {batch-id: batch-id}) err-not-found))
    (supplier (unwrap! (map-get? suppliers {supplier-id: tx-sender}) err-not-found))
    (existing-contribution (map-get? batch-contributions {batch-id: batch-id, supplier: tx-sender}))
    (prev-quantity (match existing-contribution contrib (get quantity contrib) u0))
  )
    (asserts! (get verified supplier) err-unauthorized)
    (asserts! (get active supplier) err-unauthorized)
    (asserts! (is-eq (get status batch) "open") err-invalid-params)
    (map-set batch-contributions {batch-id: batch-id, supplier: tx-sender}
      {
        quantity: (+ quantity prev-quantity),
        timestamp: stacks-block-height
      }
    )
    (map-set aggregation-batches {batch-id: batch-id}
      (merge batch {
        total-quantity: (+ (get total-quantity batch) quantity),
        num-suppliers: (if (is-none existing-contribution) (+ (get num-suppliers batch) u1) (get num-suppliers batch))
      })
    )
    (ok (map-set suppliers {supplier-id: tx-sender}
      (merge supplier {total-supplied: (+ (get total-supplied supplier) quantity)})
    ))
  )
)

(define-public (close-batch (batch-id uint))
  (let ((batch (unwrap! (map-get? aggregation-batches {batch-id: batch-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get aggregator batch)) err-unauthorized)
    (ok (map-set aggregation-batches {batch-id: batch-id}
      (merge batch {status: "closed"})
    ))
  )
)
