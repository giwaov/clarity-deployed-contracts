(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))

(define-data-var beacon-nonce uint u0)

(define-map geo-beacons
  uint
  {
    operator: principal,
    location-hash: (buff 32),
    latitude: int,
    longitude: int,
    accuracy-meters: uint,
    data-points-served: uint,
    rewards-earned: uint,
    active: bool,
    deployed-block: uint
  }
)

(define-map location-queries
  {beacon-id: uint, query-id: uint}
  {
    requester: principal,
    location-data: (buff 64),
    payment: uint,
    timestamp: uint
  }
)

(define-map beacon-coverage
  uint
  {
    coverage-radius: uint,
    devices-covered: uint,
    query-count: uint
  }
)

(define-map query-counter uint uint)
(define-map operator-beacons principal (list 100 uint))

(define-public (deploy-beacon (location (buff 32)) (lat int) (lon int) (accuracy uint))
  (let
    (
      (beacon-id (+ (var-get beacon-nonce) u1))
    )
    (map-set geo-beacons beacon-id {
      operator: tx-sender,
      location-hash: location,
      latitude: lat,
      longitude: lon,
      accuracy-meters: accuracy,
      data-points-served: u0,
      rewards-earned: u0,
      active: true,
      deployed-block: stacks-block-height
    })
    (map-set beacon-coverage beacon-id {
      coverage-radius: u1000,
      devices-covered: u0,
      query-count: u0
    })
    (map-set query-counter beacon-id u0)
    (map-set operator-beacons tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? operator-beacons tx-sender)) beacon-id) u100)))
    (var-set beacon-nonce beacon-id)
    (ok beacon-id)
  )
)

(define-public (request-location (beacon-id uint) (payment uint))
  (let
    (
      (beacon (unwrap! (map-get? geo-beacons beacon-id) err-not-found))
      (query-id (+ (default-to u0 (map-get? query-counter beacon-id)) u1))
      (location-data (get location-hash beacon))
    )
    (asserts! (get active beacon) err-not-found)
    (try! (stx-transfer? payment tx-sender (get operator beacon)))
    (map-set location-queries {beacon-id: beacon-id, query-id: query-id} {
      requester: tx-sender,
      location-data: 0x00,
      payment: payment,
      timestamp: stacks-block-height
    })
    (map-set query-counter beacon-id query-id)
    (map-set geo-beacons beacon-id (merge beacon {
      data-points-served: (+ (get data-points-served beacon) u1),
      rewards-earned: (+ (get rewards-earned beacon) payment)
    }))
    (let
      (
        (coverage (unwrap-panic (map-get? beacon-coverage beacon-id)))
      )
      (map-set beacon-coverage beacon-id (merge coverage {
        query-count: (+ (get query-count coverage) u1)
      }))
    )
    (ok query-id)
  )
)

(define-public (update-beacon-location (beacon-id uint) (lat int) (lon int) (location (buff 32)))
  (let
    (
      (beacon (unwrap! (map-get? geo-beacons beacon-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get operator beacon)) err-unauthorized)
    (map-set geo-beacons beacon-id (merge beacon {
      latitude: lat,
      longitude: lon,
      location-hash: location
    }))
    (ok true)
  )
)

(define-public (expand-coverage (beacon-id uint) (new-radius uint))
  (let
    (
      (beacon (unwrap! (map-get? geo-beacons beacon-id) err-not-found))
      (coverage (unwrap! (map-get? beacon-coverage beacon-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get operator beacon)) err-unauthorized)
    (map-set beacon-coverage beacon-id (merge coverage {coverage-radius: new-radius}))
    (ok true)
  )
)

(define-public (toggle-beacon (beacon-id uint))
  (let
    (
      (beacon (unwrap! (map-get? geo-beacons beacon-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get operator beacon)) err-unauthorized)
    (map-set geo-beacons beacon-id (merge beacon {active: (not (get active beacon))}))
    (ok true)
  )
)

(define-read-only (get-beacon (beacon-id uint))
  (ok (map-get? geo-beacons beacon-id))
)

(define-read-only (get-query (beacon-id uint) (query-id uint))
  (ok (map-get? location-queries {beacon-id: beacon-id, query-id: query-id}))
)

(define-read-only (get-coverage (beacon-id uint))
  (ok (map-get? beacon-coverage beacon-id))
)

(define-read-only (get-operator-beacons (operator principal))
  (ok (map-get? operator-beacons operator))
)

(define-read-only (calculate-beacon-efficiency (beacon-id uint))
  (let
    (
      (beacon (unwrap-panic (map-get? geo-beacons beacon-id)))
      (coverage (unwrap-panic (map-get? beacon-coverage beacon-id)))
      (queries (get query-count coverage))
      (devices (get devices-covered coverage))
    )
    (if (> devices u0)
      (ok (/ queries devices))
      (ok u0)
    )
  )
)
