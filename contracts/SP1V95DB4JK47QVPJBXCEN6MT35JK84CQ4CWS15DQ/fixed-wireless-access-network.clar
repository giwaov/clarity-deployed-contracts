(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-node-offline (err u127))

(define-data-var access-point-nonce uint u0)

(define-map fwa-access-points
  uint
  {
    operator: principal,
    location-hash: (buff 32),
    bandwidth-mbps: uint,
    connected-users: uint,
    data-delivered: uint,
    coverage-radius: uint,
    rewards-earned: uint,
    active: bool,
    deployed-block: uint
  }
)

(define-map user-connections
  {ap-id: uint, user: principal}
  {
    plan-speed: uint,
    monthly-fee: uint,
    data-consumed: uint,
    connection-quality: uint,
    connected-block: uint,
    active: bool
  }
)

(define-map network-traffic
  {ap-id: uint, traffic-id: uint}
  {
    user: principal,
    data-amount: uint,
    peak-speed: uint,
    timestamp: uint
  }
)

(define-map traffic-counter uint uint)
(define-map operator-aps principal (list 30 uint))

(define-public (deploy-access-point (location (buff 32)) (bandwidth uint) (radius uint))
  (let
    (
      (ap-id (+ (var-get access-point-nonce) u1))
    )
    (asserts! (> bandwidth u0) err-invalid-amount)
    (map-set fwa-access-points ap-id {
      operator: tx-sender,
      location-hash: location,
      bandwidth-mbps: bandwidth,
      connected-users: u0,
      data-delivered: u0,
      coverage-radius: radius,
      rewards-earned: u0,
      active: true,
      deployed-block: stacks-block-height
    })
    (map-set traffic-counter ap-id u0)
    (map-set operator-aps tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? operator-aps tx-sender)) ap-id) u30)))
    (var-set access-point-nonce ap-id)
    (ok ap-id)
  )
)

(define-public (connect-user (ap-id uint) (speed uint) (fee uint))
  (let
    (
      (ap (unwrap! (map-get? fwa-access-points ap-id) err-not-found))
    )
    (asserts! (get active ap) err-node-offline)
    (try! (stx-transfer? fee tx-sender (get operator ap)))
    (map-set user-connections {ap-id: ap-id, user: tx-sender} {
      plan-speed: speed,
      monthly-fee: fee,
      data-consumed: u0,
      connection-quality: u100,
      connected-block: stacks-block-height,
      active: true
    })
    (map-set fwa-access-points ap-id (merge ap {
      connected-users: (+ (get connected-users ap) u1)
    }))
    (ok true)
  )
)

(define-public (record-traffic (ap-id uint) (data-amount uint) (speed uint))
  (let
    (
      (ap (unwrap! (map-get? fwa-access-points ap-id) err-not-found))
      (connection (unwrap! (map-get? user-connections {ap-id: ap-id, user: tx-sender}) err-not-found))
      (traffic-id (+ (default-to u0 (map-get? traffic-counter ap-id)) u1))
    )
    (asserts! (get active connection) err-not-found)
    (map-set network-traffic {ap-id: ap-id, traffic-id: traffic-id} {
      user: tx-sender,
      data-amount: data-amount,
      peak-speed: speed,
      timestamp: stacks-block-height
    })
    (map-set traffic-counter ap-id traffic-id)
    (map-set user-connections {ap-id: ap-id, user: tx-sender}
      (merge connection {data-consumed: (+ (get data-consumed connection) data-amount)}))
    (map-set fwa-access-points ap-id (merge ap {
      data-delivered: (+ (get data-delivered ap) data-amount)
    }))
    (ok traffic-id)
  )
)

(define-public (claim-operator-rewards (ap-id uint) (reward uint))
  (let
    (
      (ap (unwrap! (map-get? fwa-access-points ap-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get operator ap)) err-unauthorized)
    (map-set fwa-access-points ap-id (merge ap {
      rewards-earned: (+ (get rewards-earned ap) reward)
    }))
    (ok true)
  )
)

(define-public (disconnect-user (ap-id uint))
  (let
    (
      (ap (unwrap! (map-get? fwa-access-points ap-id) err-not-found))
      (connection (unwrap! (map-get? user-connections {ap-id: ap-id, user: tx-sender}) err-not-found))
    )
    (map-set user-connections {ap-id: ap-id, user: tx-sender}
      (merge connection {active: false}))
    (map-set fwa-access-points ap-id (merge ap {
      connected-users: (- (get connected-users ap) u1)
    }))
    (ok true)
  )
)

(define-read-only (get-access-point (ap-id uint))
  (ok (map-get? fwa-access-points ap-id))
)

(define-read-only (get-user-connection (ap-id uint) (user principal))
  (ok (map-get? user-connections {ap-id: ap-id, user: user}))
)

(define-read-only (get-traffic (ap-id uint) (traffic-id uint))
  (ok (map-get? network-traffic {ap-id: ap-id, traffic-id: traffic-id}))
)

(define-read-only (get-operator-aps (operator principal))
  (ok (map-get? operator-aps operator))
)

(define-read-only (calculate-utilization (ap-id uint))
  (let
    (
      (ap (unwrap-panic (map-get? fwa-access-points ap-id)))
      (bandwidth (get bandwidth-mbps ap))
      (users (get connected-users ap))
    )
    (if (> bandwidth u0)
      (ok (/ (* users u100) bandwidth))
      (ok u0)
    )
  )
)
