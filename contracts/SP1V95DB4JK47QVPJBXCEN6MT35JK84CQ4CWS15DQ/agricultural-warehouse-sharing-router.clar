(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))

(define-map warehouses
  {warehouse-id: uint}
  {
    location: (string-ascii 128),
    capacity: uint,
    available: uint,
    operator: principal,
    active: bool
  }
)

(define-map allocation-requests
  {request-id: uint}
  {
    requester: principal,
    quantity: uint,
    product-type: (string-ascii 64),
    preferred-locations: (list 5 (string-ascii 128)),
    allocated-warehouse: (optional uint),
    status: (string-ascii 16),
    created-at: uint
  }
)

(define-data-var warehouse-nonce uint u0)
(define-data-var request-nonce uint u0)

(define-read-only (get-warehouse (warehouse-id uint))
  (map-get? warehouses {warehouse-id: warehouse-id})
)

(define-read-only (get-request (request-id uint))
  (map-get? allocation-requests {request-id: request-id})
)

(define-public (register-warehouse
  (location (string-ascii 128))
  (capacity uint)
)
  (let ((warehouse-id (var-get warehouse-nonce)))
    (asserts! (> capacity u0) err-invalid-params)
    (map-set warehouses {warehouse-id: warehouse-id}
      {
        location: location,
        capacity: capacity,
        available: capacity,
        operator: tx-sender,
        active: true
      }
    )
    (var-set warehouse-nonce (+ warehouse-id u1))
    (ok warehouse-id)
  )
)

(define-public (request-allocation
  (quantity uint)
  (product-type (string-ascii 64))
  (preferred-locations (list 5 (string-ascii 128)))
)
  (let ((request-id (var-get request-nonce)))
    (asserts! (> quantity u0) err-invalid-params)
    (map-set allocation-requests {request-id: request-id}
      {
        requester: tx-sender,
        quantity: quantity,
        product-type: product-type,
        preferred-locations: preferred-locations,
        allocated-warehouse: none,
        status: "pending",
        created-at: stacks-block-height
      }
    )
    (var-set request-nonce (+ request-id u1))
    (ok request-id)
  )
)

(define-public (allocate-warehouse
  (request-id uint)
  (warehouse-id uint)
)
  (let (
    (request (unwrap! (map-get? allocation-requests {request-id: request-id}) err-not-found))
    (warehouse (unwrap! (map-get? warehouses {warehouse-id: warehouse-id}) err-not-found))
  )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (asserts! (is-eq (get status request) "pending") err-invalid-params)
    (asserts! (<= (get quantity request) (get available warehouse)) err-invalid-params)
    (map-set allocation-requests {request-id: request-id}
      (merge request {
        allocated-warehouse: (some warehouse-id),
        status: "allocated"
      })
    )
    (ok (map-set warehouses {warehouse-id: warehouse-id}
      (merge warehouse {available: (- (get available warehouse) (get quantity request))})
    ))
  )
)

(define-public (release-allocation (request-id uint))
  (let (
    (request (unwrap! (map-get? allocation-requests {request-id: request-id}) err-not-found))
    (warehouse-id (unwrap! (get allocated-warehouse request) err-not-found))
    (warehouse (unwrap! (map-get? warehouses {warehouse-id: warehouse-id}) err-not-found))
  )
    (asserts! (is-eq tx-sender (get requester request)) err-unauthorized)
    (map-set allocation-requests {request-id: request-id}
      (merge request {status: "released"})
    )
    (ok (map-set warehouses {warehouse-id: warehouse-id}
      (merge warehouse {available: (+ (get available warehouse) (get quantity request))})
    ))
  )
)
