(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map distribution-centers
  uint
  {
    operator: principal,
    location: (string-ascii 128),
    storage-capacity: uint,
    current-inventory: uint,
    distribution-type: (string-ascii 64),
    active: bool
  })

(define-map distribution-orders
  uint
  {
    center-id: uint,
    customer: principal,
    volume: uint,
    delivery-address: (string-ascii 256),
    order-date: uint,
    status: (string-ascii 32)
  })

(define-data-var next-center-id uint u0)
(define-data-var next-order-id uint u0)

(define-read-only (get-center (center-id uint))
  (ok (map-get? distribution-centers center-id)))

(define-public (register-center (location (string-ascii 128)) (capacity uint) (dist-type (string-ascii 64)))
  (let ((center-id (var-get next-center-id)))
    (map-set distribution-centers center-id
      {operator: tx-sender, location: location, storage-capacity: capacity,
       current-inventory: u0, distribution-type: dist-type, active: true})
    (var-set next-center-id (+ center-id u1))
    (ok center-id)))

(define-public (place-order (center-id uint) (volume uint) (address (string-ascii 256)))
  (let ((order-id (var-get next-order-id)))
    (asserts! (is-some (map-get? distribution-centers center-id)) err-not-found)
    (map-set distribution-orders order-id
      {center-id: center-id, customer: tx-sender, volume: volume,
       delivery-address: address, order-date: stacks-block-height, status: "pending"})
    (var-set next-order-id (+ order-id u1))
    (ok order-id)))

(define-public (fulfill-order (order-id uint))
  (let ((order (unwrap! (map-get? distribution-orders order-id) err-not-found)))
    (ok (map-set distribution-orders order-id (merge order {status: "fulfilled"})))))
