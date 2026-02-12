(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-signal-lost (err u102))

(define-map satellite-signals
  uint
  {
    satellite-id: (string-ascii 32),
    latitude: int,
    longitude: int,
    altitude: uint,
    timestamp: uint,
    accuracy: uint,
    signal-strength: uint
  })

(define-map gnss-receivers
  principal
  {
    receiver-id: (string-ascii 32),
    last-position-lat: int,
    last-position-lon: int,
    last-update: uint,
    active: bool
  })

(define-data-var next-signal-id uint u0)

(define-read-only (get-signal (signal-id uint))
  (ok (map-get? satellite-signals signal-id)))

(define-read-only (get-receiver (user principal))
  (ok (map-get? gnss-receivers user)))

(define-public (log-position (sat-id (string-ascii 32)) (lat int) (lon int) (alt uint) (accuracy uint) (strength uint))
  (let ((signal-id (var-get next-signal-id)))
    (map-set satellite-signals signal-id
      {satellite-id: sat-id, latitude: lat, longitude: lon, altitude: alt,
       timestamp: stacks-block-height, accuracy: accuracy, signal-strength: strength})
    (var-set next-signal-id (+ signal-id u1))
    (ok signal-id)))

(define-public (register-receiver (receiver-id (string-ascii 32)))
  (begin
    (map-set gnss-receivers tx-sender
      {receiver-id: receiver-id, last-position-lat: 0, last-position-lon: 0,
       last-update: stacks-block-height, active: true})
    (ok true)))

(define-public (update-receiver-position (lat int) (lon int))
  (let ((receiver (unwrap! (map-get? gnss-receivers tx-sender) err-not-found)))
    (ok (map-set gnss-receivers tx-sender
      (merge receiver {last-position-lat: lat, last-position-lon: lon, last-update: stacks-block-height})))))
