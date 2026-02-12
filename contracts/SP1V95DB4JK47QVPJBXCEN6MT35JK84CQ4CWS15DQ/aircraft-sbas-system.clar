(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map sbas-stations
  (string-ascii 32)
  {
    station-name: (string-ascii 128),
    latitude: int,
    longitude: int,
    coverage-region: (string-ascii 64),
    operational: bool
  })

(define-map sbas-corrections
  uint
  {
    station-id: (string-ascii 32),
    satellite-id: (string-ascii 32),
    correction-value: int,
    ionospheric-delay: uint,
    timestamp: uint,
    validity-period: uint
  })

(define-map sbas-receivers
  principal
  {
    receiver-id: (string-ascii 32),
    corrections-applied: uint,
    accuracy-improvement: uint,
    last-update: uint
  })

(define-data-var next-correction-id uint u0)

(define-read-only (get-station (station-id (string-ascii 32)))
  (ok (map-get? sbas-stations station-id)))

(define-public (register-sbas-station (station-id (string-ascii 32)) (name (string-ascii 128)) (lat int) (lon int) (region (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set sbas-stations station-id
      {station-name: name, latitude: lat, longitude: lon, coverage-region: region, operational: true}))))

(define-public (broadcast-correction (station (string-ascii 32)) (satellite (string-ascii 32)) (correction int) (iono uint) (validity uint))
  (let ((correction-id (var-get next-correction-id)))
    (map-set sbas-corrections correction-id
      {station-id: station, satellite-id: satellite, correction-value: correction,
       ionospheric-delay: iono, timestamp: stacks-block-height, validity-period: validity})
    (var-set next-correction-id (+ correction-id u1))
    (ok correction-id)))

(define-public (register-sbas-receiver (receiver-id (string-ascii 32)))
  (begin
    (ok (map-set sbas-receivers tx-sender
      {receiver-id: receiver-id, corrections-applied: u0, accuracy-improvement: u0, last-update: stacks-block-height}))))
