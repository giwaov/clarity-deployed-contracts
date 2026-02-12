(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))

(define-map aggregation-routes
  {route-id: uint}
  {
    source-locations: (list 10 (string-ascii 128)),
    destination: (string-ascii 128),
    product-type: (string-ascii 64),
    total-capacity: uint,
    used-capacity: uint,
    coordinator: principal,
    status: (string-ascii 16)
  }
)

(define-map route-assignments
  {assignment-id: uint}
  {
    route-id: uint,
    farmer: principal,
    location: (string-ascii 128),
    quantity: uint,
    assigned-at: uint
  }
)

(define-data-var route-nonce uint u0)
(define-data-var assignment-nonce uint u0)

(define-read-only (get-route (route-id uint))
  (map-get? aggregation-routes {route-id: route-id})
)

(define-read-only (get-assignment (assignment-id uint))
  (map-get? route-assignments {assignment-id: assignment-id})
)

(define-public (create-route
  (source-locations (list 10 (string-ascii 128)))
  (destination (string-ascii 128))
  (product-type (string-ascii 64))
  (total-capacity uint)
)
  (let ((route-id (var-get route-nonce)))
    (asserts! (> total-capacity u0) err-invalid-params)
    (map-set aggregation-routes {route-id: route-id}
      {
        source-locations: source-locations,
        destination: destination,
        product-type: product-type,
        total-capacity: total-capacity,
        used-capacity: u0,
        coordinator: tx-sender,
        status: "active"
      }
    )
    (var-set route-nonce (+ route-id u1))
    (ok route-id)
  )
)

(define-public (assign-to-route
  (route-id uint)
  (location (string-ascii 128))
  (quantity uint)
)
  (let (
    (route (unwrap! (map-get? aggregation-routes {route-id: route-id}) err-not-found))
    (assignment-id (var-get assignment-nonce))
  )
    (asserts! (is-eq (get status route) "active") err-invalid-params)
    (asserts! (<= (+ (get used-capacity route) quantity) (get total-capacity route)) err-invalid-params)
    (map-set route-assignments {assignment-id: assignment-id}
      {
        route-id: route-id,
        farmer: tx-sender,
        location: location,
        quantity: quantity,
        assigned-at: stacks-block-height
      }
    )
    (map-set aggregation-routes {route-id: route-id}
      (merge route {used-capacity: (+ (get used-capacity route) quantity)})
    )
    (var-set assignment-nonce (+ assignment-id u1))
    (ok assignment-id)
  )
)

(define-public (complete-route (route-id uint))
  (let ((route (unwrap! (map-get? aggregation-routes {route-id: route-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get coordinator route)) err-unauthorized)
    (ok (map-set aggregation-routes {route-id: route-id}
      (merge route {status: "completed"})
    ))
  )
)
