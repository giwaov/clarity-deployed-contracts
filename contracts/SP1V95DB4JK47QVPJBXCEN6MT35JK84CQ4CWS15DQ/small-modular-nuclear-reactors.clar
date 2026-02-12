(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-reactor-offline (err u121))

(define-data-var reactor-nonce uint u0)

(define-map smr-reactors
  uint
  {
    operator: principal,
    capacity-mw: uint,
    current-output: uint,
    fuel-level: uint,
    safety-status: (string-ascii 20),
    location-hash: (buff 32),
    operational: bool,
    last-maintenance: uint,
    created-block: uint
  }
)

(define-map power-contracts
  {reactor-id: uint, contract-id: uint}
  {
    buyer: principal,
    allocated-mw: uint,
    price-per-mw: uint,
    duration-blocks: uint,
    start-block: uint,
    active: bool
  }
)

(define-map maintenance-logs
  {reactor-id: uint, log-id: uint}
  {
    technician: principal,
    maintenance-type: (string-ascii 30),
    fuel-added: uint,
    block: uint
  }
)

(define-map contract-counter uint uint)
(define-map log-counter uint uint)
(define-map operator-reactors principal (list 5 uint))

(define-public (deploy-smr (capacity uint) (fuel uint) (location (buff 32)))
  (let
    (
      (reactor-id (+ (var-get reactor-nonce) u1))
    )
    (asserts! (> capacity u0) err-invalid-amount)
    (map-set smr-reactors reactor-id {
      operator: tx-sender,
      capacity-mw: capacity,
      current-output: u0,
      fuel-level: fuel,
      safety-status: "nominal",
      location-hash: location,
      operational: true,
      last-maintenance: stacks-block-height,
      created-block: stacks-block-height
    })
    (map-set contract-counter reactor-id u0)
    (map-set log-counter reactor-id u0)
    (map-set operator-reactors tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? operator-reactors tx-sender)) reactor-id) u5)))
    (var-set reactor-nonce reactor-id)
    (ok reactor-id)
  )
)

(define-public (create-power-contract (reactor-id uint) (buyer principal) (mw uint) 
                                       (price uint) (duration uint))
  (let
    (
      (reactor (unwrap! (map-get? smr-reactors reactor-id) err-not-found))
      (contract-id (+ (default-to u0 (map-get? contract-counter reactor-id)) u1))
      (total-allocated (calculate-total-allocated reactor-id))
    )
    (asserts! (is-eq tx-sender (get operator reactor)) err-unauthorized)
    (asserts! (get operational reactor) err-reactor-offline)
    (asserts! (<= (+ total-allocated mw) (get capacity-mw reactor)) err-invalid-amount)
    (map-set power-contracts {reactor-id: reactor-id, contract-id: contract-id} {
      buyer: buyer,
      allocated-mw: mw,
      price-per-mw: price,
      duration-blocks: duration,
      start-block: stacks-block-height,
      active: true
    })
    (map-set contract-counter reactor-id contract-id)
    (ok contract-id)
  )
)

(define-public (pay-for-power (reactor-id uint) (contract-id uint) (payment uint))
  (let
    (
      (reactor (unwrap! (map-get? smr-reactors reactor-id) err-not-found))
      (contract (unwrap! (map-get? power-contracts {reactor-id: reactor-id, contract-id: contract-id}) err-not-found))
    )
    (asserts! (is-eq tx-sender (get buyer contract)) err-unauthorized)
    (asserts! (get active contract) err-not-found)
    (try! (stx-transfer? payment tx-sender (get operator reactor)))
    (ok true)
  )
)

(define-public (perform-maintenance (reactor-id uint) (maintenance-type (string-ascii 30)) (fuel-added uint))
  (let
    (
      (reactor (unwrap! (map-get? smr-reactors reactor-id) err-not-found))
      (log-id (+ (default-to u0 (map-get? log-counter reactor-id)) u1))
      (new-fuel (+ (get fuel-level reactor) fuel-added))
    )
    (asserts! (is-eq tx-sender (get operator reactor)) err-unauthorized)
    (map-set maintenance-logs {reactor-id: reactor-id, log-id: log-id} {
      technician: tx-sender,
      maintenance-type: maintenance-type,
      fuel-added: fuel-added,
      block: stacks-block-height
    })
    (map-set log-counter reactor-id log-id)
    (map-set smr-reactors reactor-id (merge reactor {
      fuel-level: new-fuel,
      last-maintenance: stacks-block-height
    }))
    (ok log-id)
  )
)

(define-public (update-output (reactor-id uint) (output uint))
  (let
    (
      (reactor (unwrap! (map-get? smr-reactors reactor-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get operator reactor)) err-unauthorized)
    (asserts! (<= output (get capacity-mw reactor)) err-invalid-amount)
    (map-set smr-reactors reactor-id (merge reactor {current-output: output}))
    (ok true)
  )
)

(define-read-only (get-reactor (reactor-id uint))
  (ok (map-get? smr-reactors reactor-id))
)

(define-read-only (get-power-contract (reactor-id uint) (contract-id uint))
  (ok (map-get? power-contracts {reactor-id: reactor-id, contract-id: contract-id}))
)

(define-read-only (get-maintenance-log (reactor-id uint) (log-id uint))
  (ok (map-get? maintenance-logs {reactor-id: reactor-id, log-id: log-id}))
)

(define-read-only (get-operator-reactors (operator principal))
  (ok (map-get? operator-reactors operator))
)

(define-read-only (calculate-total-allocated (reactor-id uint))
  u0
)

(define-read-only (calculate-capacity-factor (reactor-id uint))
  (let
    (
      (reactor (unwrap-panic (map-get? smr-reactors reactor-id)))
      (capacity (get capacity-mw reactor))
      (output (get current-output reactor))
    )
    (if (> capacity u0)
      (ok (/ (* output u100) capacity))
      (ok u0)
    )
  )
)
