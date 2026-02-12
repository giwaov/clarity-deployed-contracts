(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-driver-busy (err u129))

(define-data-var ride-nonce uint u0)

(define-map rides
  uint
  {
    rider: principal,
    driver: principal,
    pickup-location: (buff 32),
    dropoff-location: (buff 32),
    fare: uint,
    distance: uint,
    status: (string-ascii 20),
    requested-block: uint,
    completed-block: uint
  }
)

(define-map drivers
  principal
  {
    active: bool,
    total-rides: uint,
    earnings: uint,
    rating: uint,
    location-hash: (buff 32),
    vehicle-type: (string-ascii 20),
    available: bool
  }
)

(define-map riders
  principal
  {
    total-rides: uint,
    total-spent: uint,
    rating: uint
  }
)

(define-map driver-rides principal (list 500 uint))
(define-map rider-rides principal (list 200 uint))

(define-public (register-driver (vehicle-type (string-ascii 20)) (location (buff 32)))
  (begin
    (map-set drivers tx-sender {
      active: true,
      total-rides: u0,
      earnings: u0,
      rating: u100,
      location-hash: location,
      vehicle-type: vehicle-type,
      available: true
    })
    (ok true)
  )
)

(define-public (request-ride (pickup (buff 32)) (dropoff (buff 32)) (fare uint) (distance uint))
  (let
    (
      (ride-id (+ (var-get ride-nonce) u1))
    )
    (asserts! (> fare u0) err-invalid-amount)
    (map-set rides ride-id {
      rider: tx-sender,
      driver: tx-sender,
      pickup-location: pickup,
      dropoff-location: dropoff,
      fare: fare,
      distance: distance,
      status: "requested",
      requested-block: stacks-block-height,
      completed-block: u0
    })
    (let
      (
        (rider-data (default-to {total-rides: u0, total-spent: u0, rating: u100} 
                     (map-get? riders tx-sender)))
      )
      (map-set riders tx-sender rider-data)
    )
    (map-set rider-rides tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? rider-rides tx-sender)) ride-id) u200)))
    (var-set ride-nonce ride-id)
    (ok ride-id)
  )
)

(define-public (accept-ride (ride-id uint))
  (let
    (
      (ride (unwrap! (map-get? rides ride-id) err-not-found))
      (driver-data (unwrap! (map-get? drivers tx-sender) err-not-found))
    )
    (asserts! (get available driver-data) err-driver-busy)
    (asserts! (is-eq (get status ride) "requested") err-unauthorized)
    (map-set rides ride-id (merge ride {driver: tx-sender, status: "accepted"}))
    (map-set drivers tx-sender (merge driver-data {available: false}))
    (map-set driver-rides tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? driver-rides tx-sender)) ride-id) u500)))
    (ok true)
  )
)

(define-public (start-ride (ride-id uint))
  (let
    (
      (ride (unwrap! (map-get? rides ride-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get driver ride)) err-unauthorized)
    (asserts! (is-eq (get status ride) "accepted") err-unauthorized)
    (map-set rides ride-id (merge ride {status: "in-progress"}))
    (ok true)
  )
)

(define-public (complete-ride (ride-id uint))
  (let
    (
      (ride (unwrap! (map-get? rides ride-id) err-not-found))
      (driver-data (unwrap! (map-get? drivers tx-sender) err-not-found))
      (rider-data (unwrap! (map-get? riders (get rider ride)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get driver ride)) err-unauthorized)
    (asserts! (is-eq (get status ride) "in-progress") err-unauthorized)
    (try! (stx-transfer? (get fare ride) (get rider ride) tx-sender))
    (map-set rides ride-id (merge ride {
      status: "completed",
      completed-block: stacks-block-height
    }))
    (map-set drivers tx-sender (merge driver-data {
      total-rides: (+ (get total-rides driver-data) u1),
      earnings: (+ (get earnings driver-data) (get fare ride)),
      available: true
    }))
    (map-set riders (get rider ride) (merge rider-data {
      total-rides: (+ (get total-rides rider-data) u1),
      total-spent: (+ (get total-spent rider-data) (get fare ride))
    }))
    (ok true)
  )
)

(define-public (cancel-ride (ride-id uint))
  (let
    (
      (ride (unwrap! (map-get? rides ride-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get rider ride)) err-unauthorized)
    (map-set rides ride-id (merge ride {status: "cancelled"}))
    (ok true)
  )
)

(define-read-only (get-ride (ride-id uint))
  (ok (map-get? rides ride-id))
)

(define-read-only (get-driver (driver principal))
  (ok (map-get? drivers driver))
)

(define-read-only (get-rider (rider principal))
  (ok (map-get? riders rider))
)

(define-read-only (get-driver-rides (driver principal))
  (ok (map-get? driver-rides driver))
)

(define-read-only (get-rider-rides (rider principal))
  (ok (map-get? rider-rides rider))
)
