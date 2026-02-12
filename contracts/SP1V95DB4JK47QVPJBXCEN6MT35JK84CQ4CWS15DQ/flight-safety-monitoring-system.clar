(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-critical-alert (err u102))

(define-map flight-safety-data
  uint
  {
    flight-number: (string-ascii 32),
    aircraft-id: (string-ascii 32),
    altitude: uint,
    speed: uint,
    heading: uint,
    fuel-level: uint,
    system-status: (string-ascii 32),
    timestamp: uint
  })

(define-map safety-alerts
  uint
  {
    flight-number: (string-ascii 32),
    alert-type: (string-ascii 64),
    severity: (string-ascii 16),
    description: (string-ascii 256),
    timestamp: uint,
    resolved: bool
  })

(define-data-var next-data-id uint u0)
(define-data-var next-alert-id uint u0)

(define-read-only (get-safety-data (data-id uint))
  (ok (map-get? flight-safety-data data-id)))

(define-read-only (get-alert (alert-id uint))
  (ok (map-get? safety-alerts alert-id)))

(define-public (log-flight-data (flight (string-ascii 32)) (aircraft (string-ascii 32)) (alt uint) (speed uint) (heading uint) (fuel uint) (status (string-ascii 32)))
  (let ((data-id (var-get next-data-id)))
    (map-set flight-safety-data data-id
      {flight-number: flight, aircraft-id: aircraft, altitude: alt, speed: speed,
       heading: heading, fuel-level: fuel, system-status: status, timestamp: stacks-block-height})
    (var-set next-data-id (+ data-id u1))
    (ok data-id)))

(define-public (create-alert (flight (string-ascii 32)) (type (string-ascii 64)) (severity (string-ascii 16)) (desc (string-ascii 256)))
  (let ((alert-id (var-get next-alert-id)))
    (map-set safety-alerts alert-id
      {flight-number: flight, alert-type: type, severity: severity,
       description: desc, timestamp: stacks-block-height, resolved: false})
    (var-set next-alert-id (+ alert-id u1))
    (ok alert-id)))

(define-public (resolve-alert (alert-id uint))
  (let ((alert (unwrap! (map-get? safety-alerts alert-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set safety-alerts alert-id (merge alert {resolved: true})))))
