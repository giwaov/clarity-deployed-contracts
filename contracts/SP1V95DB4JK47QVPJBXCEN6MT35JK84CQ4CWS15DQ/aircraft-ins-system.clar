(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map ins-systems
  (string-ascii 32)
  {
    aircraft-id: (string-ascii 32),
    position-lat: int,
    position-lon: int,
    altitude: uint,
    velocity: uint,
    heading: uint,
    last-update: uint,
    calibrated: bool
  })

(define-map gyroscope-data
  {aircraft-id: (string-ascii 32), timestamp: uint}
  {roll: int, pitch: int, yaw: int})

(define-map accelerometer-data
  {aircraft-id: (string-ascii 32), timestamp: uint}
  {accel-x: int, accel-y: int, accel-z: int})

(define-read-only (get-ins (system-id (string-ascii 32)))
  (ok (map-get? ins-systems system-id)))

(define-public (initialize-ins (system-id (string-ascii 32)) (aircraft (string-ascii 32)) (lat int) (lon int) (alt uint))
  (begin
    (ok (map-set ins-systems system-id
      {aircraft-id: aircraft, position-lat: lat, position-lon: lon, altitude: alt,
       velocity: u0, heading: u0, last-update: stacks-block-height, calibrated: false}))))

(define-public (calibrate-ins (system-id (string-ascii 32)))
  (let ((ins (unwrap! (map-get? ins-systems system-id) err-not-found)))
    (ok (map-set ins-systems system-id (merge ins {calibrated: true})))))

(define-public (update-ins (system-id (string-ascii 32)) (lat int) (lon int) (alt uint) (vel uint) (heading uint))
  (let ((ins (unwrap! (map-get? ins-systems system-id) err-not-found)))
    (ok (map-set ins-systems system-id
      (merge ins {position-lat: lat, position-lon: lon, altitude: alt,
                  velocity: vel, heading: heading, last-update: stacks-block-height})))))

(define-public (log-gyro (aircraft (string-ascii 32)) (roll int) (pitch int) (yaw int))
  (begin
    (ok (map-set gyroscope-data {aircraft-id: aircraft, timestamp: stacks-block-height}
      {roll: roll, pitch: pitch, yaw: yaw}))))
