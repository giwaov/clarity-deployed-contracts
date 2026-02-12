(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-conflict (err u102))
(define-constant err-unauthorized (err u103))

(define-map flight-clearances
  uint
  {
    flight-number: (string-ascii 32),
    aircraft-id: (string-ascii 32),
    departure-airport: (string-ascii 8),
    arrival-airport: (string-ascii 8),
    altitude: uint,
    route: (string-ascii 256),
    clearance-time: uint,
    status: (string-ascii 32)
  })

(define-map airspace-sectors
  (string-ascii 64)
  {controller: principal, active-flights: uint, capacity: uint})

(define-data-var next-clearance-id uint u0)

(define-read-only (get-clearance (clearance-id uint))
  (ok (map-get? flight-clearances clearance-id)))

(define-public (request-clearance (flight (string-ascii 32)) (aircraft (string-ascii 32)) (departure (string-ascii 8)) (arrival (string-ascii 8)) (alt uint) (route (string-ascii 256)))
  (let ((clearance-id (var-get next-clearance-id)))
    (map-set flight-clearances clearance-id
      {flight-number: flight, aircraft-id: aircraft, departure-airport: departure,
       arrival-airport: arrival, altitude: alt, route: route,
       clearance-time: stacks-block-height, status: "pending"})
    (var-set next-clearance-id (+ clearance-id u1))
    (ok clearance-id)))

(define-public (grant-clearance (clearance-id uint))
  (let ((clearance (unwrap! (map-get? flight-clearances clearance-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set flight-clearances clearance-id (merge clearance {status: "cleared"})))))

(define-public (update-flight-status (clearance-id uint) (status (string-ascii 32)))
  (let ((clearance (unwrap! (map-get? flight-clearances clearance-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set flight-clearances clearance-id (merge clearance {status: status})))))
