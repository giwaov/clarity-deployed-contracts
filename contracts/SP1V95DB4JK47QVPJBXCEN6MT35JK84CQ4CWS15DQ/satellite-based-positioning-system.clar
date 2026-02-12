(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map positioning-satellites
  (string-ascii 32)
  {
    constellation: (string-ascii 32),
    orbit-altitude: uint,
    signal-frequency: uint,
    coverage-area: (string-ascii 64),
    launch-date: uint,
    operational: bool
  })

(define-map ground-stations
  (string-ascii 32)
  {location: (string-ascii 128), latitude: int, longitude: int, active: bool})

(define-map position-calculations
  uint
  {
    user: principal,
    latitude: int,
    longitude: int,
    altitude: uint,
    precision: uint,
    timestamp: uint
  })

(define-data-var next-calc-id uint u0)

(define-read-only (get-satellite (sat-id (string-ascii 32)))
  (ok (map-get? positioning-satellites sat-id)))

(define-public (deploy-satellite (sat-id (string-ascii 32)) (constellation (string-ascii 32)) (orbit uint) (freq uint) (coverage (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set positioning-satellites sat-id
      {constellation: constellation, orbit-altitude: orbit, signal-frequency: freq,
       coverage-area: coverage, launch-date: stacks-block-height, operational: true}))))

(define-public (add-ground-station (station-id (string-ascii 32)) (location (string-ascii 128)) (lat int) (lon int))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set ground-stations station-id
      {location: location, latitude: lat, longitude: lon, active: true}))))

(define-public (calculate-position (lat int) (lon int) (alt uint) (precision uint))
  (let ((calc-id (var-get next-calc-id)))
    (map-set position-calculations calc-id
      {user: tx-sender, latitude: lat, longitude: lon, altitude: alt,
       precision: precision, timestamp: stacks-block-height})
    (var-set next-calc-id (+ calc-id u1))
    (ok calc-id)))
