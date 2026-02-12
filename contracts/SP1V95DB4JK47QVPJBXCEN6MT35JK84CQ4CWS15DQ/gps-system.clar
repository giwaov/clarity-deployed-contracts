(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map gps-satellites
  (string-ascii 32)
  {orbit-slot: uint, health-status: (string-ascii 32), signal-accuracy: uint, operational: bool})

(define-map position-fixes
  uint
  {
    user: principal,
    latitude: int,
    longitude: int,
    altitude: uint,
    satellites-used: uint,
    hdop: uint,
    timestamp: uint
  })

(define-data-var next-fix-id uint u0)

(define-read-only (get-satellite (sat-id (string-ascii 32)))
  (ok (map-get? gps-satellites sat-id)))

(define-read-only (get-fix (fix-id uint))
  (ok (map-get? position-fixes fix-id)))

(define-public (register-satellite (sat-id (string-ascii 32)) (orbit uint) (accuracy uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set gps-satellites sat-id
      {orbit-slot: orbit, health-status: "healthy", signal-accuracy: accuracy, operational: true}))))

(define-public (update-satellite-health (sat-id (string-ascii 32)) (status (string-ascii 32)))
  (let ((satellite (unwrap! (map-get? gps-satellites sat-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set gps-satellites sat-id (merge satellite {health-status: status})))))

(define-public (record-position (lat int) (lon int) (alt uint) (sats uint) (hdop uint))
  (let ((fix-id (var-get next-fix-id)))
    (map-set position-fixes fix-id
      {user: tx-sender, latitude: lat, longitude: lon, altitude: alt,
       satellites-used: sats, hdop: hdop, timestamp: stacks-block-height})
    (var-set next-fix-id (+ fix-id u1))
    (ok fix-id)))
