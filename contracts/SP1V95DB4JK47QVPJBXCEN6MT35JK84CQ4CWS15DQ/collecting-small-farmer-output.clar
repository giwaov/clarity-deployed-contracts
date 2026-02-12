(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))

(define-map farmers
  {farmer-id: principal}
  {
    name: (string-ascii 128),
    location: (string-ascii 128),
    verified: bool,
    total-output: uint,
    active: bool
  }
)

(define-map collections
  {collection-id: uint}
  {
    farmer: principal,
    crop-type: (string-ascii 64),
    quantity: uint,
    quality-grade: (string-ascii 16),
    collection-date: uint,
    aggregator: principal,
    status: (string-ascii 32)
  }
)

(define-map aggregators
  {aggregator-id: principal}
  {
    name: (string-ascii 128),
    verified: bool,
    total-collected: uint
  }
)

(define-data-var collection-nonce uint u0)

(define-read-only (get-farmer (farmer-id principal))
  (map-get? farmers {farmer-id: farmer-id})
)

(define-read-only (get-collection (collection-id uint))
  (map-get? collections {collection-id: collection-id})
)

(define-read-only (get-aggregator (aggregator-id principal))
  (map-get? aggregators {aggregator-id: aggregator-id})
)

(define-public (register-farmer
  (farmer-id principal)
  (name (string-ascii 128))
  (location (string-ascii 128))
)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set farmers {farmer-id: farmer-id}
      {
        name: name,
        location: location,
        verified: true,
        total-output: u0,
        active: true
      }
    ))
  )
)

(define-public (register-aggregator
  (aggregator-id principal)
  (name (string-ascii 128))
)
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set aggregators {aggregator-id: aggregator-id}
      {
        name: name,
        verified: true,
        total-collected: u0
      }
    ))
  )
)

(define-public (record-collection
  (farmer principal)
  (crop-type (string-ascii 64))
  (quantity uint)
  (quality-grade (string-ascii 16))
)
  (let (
    (collection-id (var-get collection-nonce))
    (farmer-data (unwrap! (map-get? farmers {farmer-id: farmer}) err-not-found))
    (aggregator-data (unwrap! (map-get? aggregators {aggregator-id: tx-sender}) err-not-found))
  )
    (asserts! (get verified farmer-data) err-unauthorized)
    (asserts! (get verified aggregator-data) err-unauthorized)
    (map-set collections {collection-id: collection-id}
      {
        farmer: farmer,
        crop-type: crop-type,
        quantity: quantity,
        quality-grade: quality-grade,
        collection-date: stacks-block-height,
        aggregator: tx-sender,
        status: "collected"
      }
    )
    (map-set farmers {farmer-id: farmer}
      (merge farmer-data {total-output: (+ (get total-output farmer-data) quantity)})
    )
    (map-set aggregators {aggregator-id: tx-sender}
      (merge aggregator-data {total-collected: (+ (get total-collected aggregator-data) quantity)})
    )
    (var-set collection-nonce (+ collection-id u1))
    (ok collection-id)
  )
)

(define-public (update-collection-status
  (collection-id uint)
  (new-status (string-ascii 32))
)
  (let ((collection (unwrap! (map-get? collections {collection-id: collection-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get aggregator collection)) err-unauthorized)
    (ok (map-set collections {collection-id: collection-id}
      (merge collection {status: new-status})
    ))
  )
)
