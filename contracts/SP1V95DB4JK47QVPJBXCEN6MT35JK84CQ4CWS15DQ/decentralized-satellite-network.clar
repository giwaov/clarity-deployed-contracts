(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-satellite-offline (err u130))

(define-data-var satellite-nonce uint u0)

(define-map satellites
  uint
  {
    operator: principal,
    orbital-slot: (string-ascii 30),
    bandwidth-ghz: uint,
    coverage-area: uint,
    data-relayed: uint,
    uptime-percentage: uint,
    rewards-earned: uint,
    operational: bool,
    launched-block: uint
  }
)

(define-map ground-stations
  {satellite-id: uint, station-id: uint}
  {
    operator: principal,
    location-hash: (buff 32),
    uplink-capacity: uint,
    downlink-capacity: uint,
    active: bool
  }
)

(define-map data-transmissions
  {satellite-id: uint, transmission-id: uint}
  {
    sender: principal,
    receiver: principal,
    data-volume: uint,
    frequency-band: (string-ascii 20),
    cost: uint,
    timestamp: uint
  }
)

(define-map station-counter uint uint)
(define-map transmission-counter uint uint)
(define-map operator-satellites principal (list 20 uint))

(define-public (launch-satellite (orbital-slot (string-ascii 30)) (bandwidth uint) (coverage uint))
  (let
    (
      (satellite-id (+ (var-get satellite-nonce) u1))
    )
    (asserts! (> bandwidth u0) err-invalid-amount)
    (map-set satellites satellite-id {
      operator: tx-sender,
      orbital-slot: orbital-slot,
      bandwidth-ghz: bandwidth,
      coverage-area: coverage,
      data-relayed: u0,
      uptime-percentage: u100,
      rewards-earned: u0,
      operational: true,
      launched-block: stacks-block-height
    })
    (map-set station-counter satellite-id u0)
    (map-set transmission-counter satellite-id u0)
    (map-set operator-satellites tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? operator-satellites tx-sender)) satellite-id) u20)))
    (var-set satellite-nonce satellite-id)
    (ok satellite-id)
  )
)

(define-public (add-ground-station (satellite-id uint) (location (buff 32)) (uplink uint) (downlink uint))
  (let
    (
      (satellite (unwrap! (map-get? satellites satellite-id) err-not-found))
      (station-id (+ (default-to u0 (map-get? station-counter satellite-id)) u1))
    )
    (map-set ground-stations {satellite-id: satellite-id, station-id: station-id} {
      operator: tx-sender,
      location-hash: location,
      uplink-capacity: uplink,
      downlink-capacity: downlink,
      active: true
    })
    (map-set station-counter satellite-id station-id)
    (ok station-id)
  )
)

(define-public (transmit-data (satellite-id uint) (receiver principal) (volume uint) 
                               (frequency (string-ascii 20)) (cost uint))
  (let
    (
      (satellite (unwrap! (map-get? satellites satellite-id) err-not-found))
      (transmission-id (+ (default-to u0 (map-get? transmission-counter satellite-id)) u1))
    )
    (asserts! (get operational satellite) err-satellite-offline)
    (try! (stx-transfer? cost tx-sender (get operator satellite)))
    (map-set data-transmissions {satellite-id: satellite-id, transmission-id: transmission-id} {
      sender: tx-sender,
      receiver: receiver,
      data-volume: volume,
      frequency-band: frequency,
      cost: cost,
      timestamp: stacks-block-height
    })
    (map-set transmission-counter satellite-id transmission-id)
    (map-set satellites satellite-id (merge satellite {
      data-relayed: (+ (get data-relayed satellite) volume),
      rewards-earned: (+ (get rewards-earned satellite) cost)
    }))
    (ok transmission-id)
  )
)

(define-public (update-satellite-status (satellite-id uint) (operational bool) (uptime uint))
  (let
    (
      (satellite (unwrap! (map-get? satellites satellite-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get operator satellite)) err-unauthorized)
    (map-set satellites satellite-id (merge satellite {
      operational: operational,
      uptime-percentage: uptime
    }))
    (ok true)
  )
)

(define-public (toggle-ground-station (satellite-id uint) (station-id uint))
  (let
    (
      (satellite (unwrap! (map-get? satellites satellite-id) err-not-found))
      (station (unwrap! (map-get? ground-stations {satellite-id: satellite-id, station-id: station-id}) err-not-found))
    )
    (asserts! (is-eq tx-sender (get operator satellite)) err-unauthorized)
    (map-set ground-stations {satellite-id: satellite-id, station-id: station-id}
      (merge station {active: (not (get active station))}))
    (ok true)
  )
)

(define-read-only (get-satellite (satellite-id uint))
  (ok (map-get? satellites satellite-id))
)

(define-read-only (get-ground-station (satellite-id uint) (station-id uint))
  (ok (map-get? ground-stations {satellite-id: satellite-id, station-id: station-id}))
)

(define-read-only (get-transmission (satellite-id uint) (transmission-id uint))
  (ok (map-get? data-transmissions {satellite-id: satellite-id, transmission-id: transmission-id}))
)

(define-read-only (get-operator-satellites (operator principal))
  (ok (map-get? operator-satellites operator))
)

(define-read-only (calculate-bandwidth-utilization (satellite-id uint))
  (let
    (
      (satellite (unwrap-panic (map-get? satellites satellite-id)))
      (bandwidth (get bandwidth-ghz satellite))
      (data-relayed (get data-relayed satellite))
    )
    (if (> bandwidth u0)
      (ok (/ (* data-relayed u100) bandwidth))
      (ok u0)
    )
  )
)
