(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map flight-plans-fms
  uint
  {
    aircraft-id: (string-ascii 32),
    departure: (string-ascii 8),
    destination: (string-ascii 8),
    route: (string-ascii 512),
    cruise-altitude: uint,
    cruise-speed: uint,
    fuel-plan: uint,
    active: bool
  })

(define-map waypoint-database
  (string-ascii 16)
  {latitude: int, longitude: int, altitude: uint, waypoint-type: (string-ascii 32)})

(define-map navigation-status
  (string-ascii 32)
  {current-lat: int, current-lon: int, current-alt: uint, next-waypoint: (string-ascii 16)})

(define-data-var next-plan-id uint u0)

(define-read-only (get-fms-plan (plan-id uint))
  (ok (map-get? flight-plans-fms plan-id)))

(define-public (create-fms-plan (aircraft (string-ascii 32)) (dep (string-ascii 8)) (dest (string-ascii 8)) (route (string-ascii 512)) (alt uint) (speed uint) (fuel uint))
  (let ((plan-id (var-get next-plan-id)))
    (map-set flight-plans-fms plan-id
      {aircraft-id: aircraft, departure: dep, destination: dest, route: route,
       cruise-altitude: alt, cruise-speed: speed, fuel-plan: fuel, active: true})
    (var-set next-plan-id (+ plan-id u1))
    (ok plan-id)))

(define-public (add-waypoint-fms (waypoint (string-ascii 16)) (lat int) (lon int) (alt uint) (type (string-ascii 32)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set waypoint-database waypoint
      {latitude: lat, longitude: lon, altitude: alt, waypoint-type: type}))))

(define-public (update-nav-status (aircraft (string-ascii 32)) (lat int) (lon int) (alt uint) (next (string-ascii 16)))
  (begin
    (ok (map-set navigation-status aircraft
      {current-lat: lat, current-lon: lon, current-alt: alt, next-waypoint: next}))))
