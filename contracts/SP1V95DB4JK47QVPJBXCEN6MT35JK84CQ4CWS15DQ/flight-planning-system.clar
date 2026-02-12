(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-route (err u102))

(define-map flight-plans
  uint
  {
    flight-number: (string-ascii 32),
    aircraft-type: (string-ascii 32),
    departure: (string-ascii 8),
    destination: (string-ascii 8),
    cruise-altitude: uint,
    cruise-speed: uint,
    route: (string-ascii 512),
    fuel-required: uint,
    estimated-time: uint,
    filed-at: uint,
    approved: bool
  })

(define-map waypoints
  (string-ascii 16)
  {latitude: int, longitude: int, altitude: uint})

(define-data-var next-plan-id uint u0)

(define-read-only (get-flight-plan (plan-id uint))
  (ok (map-get? flight-plans plan-id)))

(define-public (file-flight-plan (flight (string-ascii 32)) (aircraft (string-ascii 32)) (dep (string-ascii 8)) (dest (string-ascii 8)) (alt uint) (speed uint) (route (string-ascii 512)) (fuel uint) (eta uint))
  (let ((plan-id (var-get next-plan-id)))
    (map-set flight-plans plan-id
      {flight-number: flight, aircraft-type: aircraft, departure: dep, destination: dest,
       cruise-altitude: alt, cruise-speed: speed, route: route, fuel-required: fuel,
       estimated-time: eta, filed-at: stacks-block-height, approved: false})
    (var-set next-plan-id (+ plan-id u1))
    (ok plan-id)))

(define-public (approve-flight-plan (plan-id uint))
  (let ((plan (unwrap! (map-get? flight-plans plan-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set flight-plans plan-id (merge plan {approved: true})))))

(define-public (add-waypoint (name (string-ascii 16)) (lat int) (lon int) (alt uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set waypoints name {latitude: lat, longitude: lon, altitude: alt}))))
