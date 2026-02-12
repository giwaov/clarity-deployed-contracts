(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-offline (err u119))

(define-data-var plant-nonce uint u0)

(define-map virtual-plants
  uint
  {
    operator: principal,
    total-capacity: uint,
    available-capacity: uint,
    energy-price: uint,
    location-hash: (buff 32),
    active: bool,
    uptime-percentage: uint,
    created-block: uint
  }
)

(define-map energy-devices
  {plant-id: uint, device-id: uint}
  {
    owner: principal,
    capacity: uint,
    device-type: (string-ascii 20),
    contribution: uint,
    rewards-earned: uint,
    online: bool
  }
)

(define-map energy-trades
  {plant-id: uint, trade-id: uint}
  {
    buyer: principal,
    amount: uint,
    price: uint,
    block: uint
  }
)

(define-map device-counter uint uint)
(define-map trade-counter uint uint)
(define-map operator-plants principal (list 20 uint))

(define-public (create-vpp (capacity uint) (price uint) (location (buff 32)))
  (let
    (
      (plant-id (+ (var-get plant-nonce) u1))
    )
    (asserts! (> capacity u0) err-invalid-amount)
    (map-set virtual-plants plant-id {
      operator: tx-sender,
      total-capacity: capacity,
      available-capacity: capacity,
      energy-price: price,
      location-hash: location,
      active: true,
      uptime-percentage: u100,
      created-block: stacks-block-height
    })
    (map-set device-counter plant-id u0)
    (map-set trade-counter plant-id u0)
    (map-set operator-plants tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? operator-plants tx-sender)) plant-id) u20)))
    (var-set plant-nonce plant-id)
    (ok plant-id)
  )
)

(define-public (register-device (plant-id uint) (capacity uint) (device-type (string-ascii 20)))
  (let
    (
      (plant (unwrap! (map-get? virtual-plants plant-id) err-not-found))
      (device-id (+ (default-to u0 (map-get? device-counter plant-id)) u1))
      (new-capacity (+ (get total-capacity plant) capacity))
    )
    (map-set energy-devices {plant-id: plant-id, device-id: device-id} {
      owner: tx-sender,
      capacity: capacity,
      device-type: device-type,
      contribution: u0,
      rewards-earned: u0,
      online: true
    })
    (map-set device-counter plant-id device-id)
    (map-set virtual-plants plant-id (merge plant {
      total-capacity: new-capacity,
      available-capacity: (+ (get available-capacity plant) capacity)
    }))
    (ok device-id)
  )
)

(define-public (purchase-energy (plant-id uint) (amount uint))
  (let
    (
      (plant (unwrap! (map-get? virtual-plants plant-id) err-not-found))
      (cost (* amount (get energy-price plant)))
      (trade-id (+ (default-to u0 (map-get? trade-counter plant-id)) u1))
    )
    (asserts! (get active plant) err-offline)
    (asserts! (<= amount (get available-capacity plant)) err-invalid-amount)
    (try! (stx-transfer? cost tx-sender (get operator plant)))
    (map-set energy-trades {plant-id: plant-id, trade-id: trade-id} {
      buyer: tx-sender,
      amount: amount,
      price: (get energy-price plant),
      block: stacks-block-height
    })
    (map-set trade-counter plant-id trade-id)
    (map-set virtual-plants plant-id (merge plant {
      available-capacity: (- (get available-capacity plant) amount)
    }))
    (ok trade-id)
  )
)

(define-public (update-device-contribution (plant-id uint) (device-id uint) (contribution uint))
  (let
    (
      (plant (unwrap! (map-get? virtual-plants plant-id) err-not-found))
      (device (unwrap! (map-get? energy-devices {plant-id: plant-id, device-id: device-id}) err-not-found))
    )
    (asserts! (is-eq tx-sender (get operator plant)) err-unauthorized)
    (map-set energy-devices {plant-id: plant-id, device-id: device-id}
      (merge device {contribution: (+ (get contribution device) contribution)}))
    (ok true)
  )
)

(define-read-only (get-plant (plant-id uint))
  (ok (map-get? virtual-plants plant-id))
)

(define-read-only (get-device (plant-id uint) (device-id uint))
  (ok (map-get? energy-devices {plant-id: plant-id, device-id: device-id}))
)

(define-read-only (get-trade (plant-id uint) (trade-id uint))
  (ok (map-get? energy-trades {plant-id: plant-id, trade-id: trade-id}))
)

(define-read-only (get-operator-plants (operator principal))
  (ok (map-get? operator-plants operator))
)

(define-read-only (calculate-capacity-utilization (plant-id uint))
  (let
    (
      (plant (unwrap-panic (map-get? virtual-plants plant-id)))
      (total (get total-capacity plant))
      (available (get available-capacity plant))
    )
    (if (> total u0)
      (ok (/ (* (- total available) u100) total))
      (ok u0)
    )
  )
)
