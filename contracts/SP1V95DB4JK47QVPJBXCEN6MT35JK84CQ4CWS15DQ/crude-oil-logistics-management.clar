(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map logistics-routes
  uint
  {
    operator: principal,
    origin: (string-ascii 128),
    destination: (string-ascii 128),
    transport-mode: (string-ascii 32),
    capacity: uint,
    cost-per-barrel: uint,
    active: bool
  })

(define-map logistics-shipments
  uint
  {
    route-id: uint,
    volume: uint,
    departure-time: uint,
    arrival-time: uint,
    status: (string-ascii 32),
    cost: uint
  })

(define-data-var next-route-id uint u0)
(define-data-var next-logistics-shipment-id uint u0)

(define-read-only (get-route (route-id uint))
  (ok (map-get? logistics-routes route-id)))

(define-public (create-route (origin (string-ascii 128)) (dest (string-ascii 128)) (mode (string-ascii 32)) (capacity uint) (cost uint))
  (let ((route-id (var-get next-route-id)))
    (map-set logistics-routes route-id
      {operator: tx-sender, origin: origin, destination: dest,
       transport-mode: mode, capacity: capacity, cost-per-barrel: cost, active: true})
    (var-set next-route-id (+ route-id u1))
    (ok route-id)))

(define-public (schedule-logistics (route-id uint) (volume uint) (arrival uint))
  (let ((shipment-id (var-get next-logistics-shipment-id))
        (route (unwrap! (map-get? logistics-routes route-id) err-not-found))
        (total-cost (* volume (get cost-per-barrel route))))
    (map-set logistics-shipments shipment-id
      {route-id: route-id, volume: volume, departure-time: stacks-block-height,
       arrival-time: arrival, status: "scheduled", cost: total-cost})
    (var-set next-logistics-shipment-id (+ shipment-id u1))
    (ok shipment-id)))
