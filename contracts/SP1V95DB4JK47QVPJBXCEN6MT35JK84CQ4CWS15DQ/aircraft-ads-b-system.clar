(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map adsb-transponders
  (string-ascii 32)
  {
    aircraft-id: (string-ascii 32),
    icao-address: (string-ascii 16),
    callsign: (string-ascii 16),
    latitude: int,
    longitude: int,
    altitude: uint,
    velocity: uint,
    heading: uint,
    squawk-code: (string-ascii 8),
    last-broadcast: uint
  })

(define-map adsb-receivers
  principal
  {
    receiver-id: (string-ascii 32),
    location-lat: int,
    location-lon: int,
    coverage-radius: uint,
    aircraft-tracked: uint
  })

(define-map traffic-data
  uint
  {
    transponder-id: (string-ascii 32),
    nearby-aircraft: (list 20 (string-ascii 32)),
    timestamp: uint
  })

(define-data-var next-traffic-id uint u0)

(define-read-only (get-transponder (transponder-id (string-ascii 32)))
  (ok (map-get? adsb-transponders transponder-id)))

(define-public (register-transponder (transponder-id (string-ascii 32)) (aircraft (string-ascii 32)) (icao (string-ascii 16)) (callsign (string-ascii 16)))
  (begin
    (ok (map-set adsb-transponders transponder-id
      {aircraft-id: aircraft, icao-address: icao, callsign: callsign,
       latitude: 0, longitude: 0, altitude: u0, velocity: u0, heading: u0,
       squawk-code: "1200", last-broadcast: stacks-block-height}))))

(define-public (broadcast-position (transponder-id (string-ascii 32)) (lat int) (lon int) (alt uint) (vel uint) (heading uint))
  (let ((transponder (unwrap! (map-get? adsb-transponders transponder-id) err-not-found)))
    (ok (map-set adsb-transponders transponder-id
      (merge transponder {latitude: lat, longitude: lon, altitude: alt,
                          velocity: vel, heading: heading, last-broadcast: stacks-block-height})))))

(define-public (register-adsb-receiver (receiver-id (string-ascii 32)) (lat int) (lon int) (radius uint))
  (begin
    (ok (map-set adsb-receivers tx-sender
      {receiver-id: receiver-id, location-lat: lat, location-lon: lon,
       coverage-radius: radius, aircraft-tracked: u0}))))
