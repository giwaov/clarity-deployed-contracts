(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-UNIT-NOT-FOUND (err u101))
(define-constant ERR-INSUFFICIENT-CAPACITY (err u102))

(define-map battery-systems
  { system-id: uint }
  {
    owner: principal,
    location: (string-ascii 100),
    capacity-kwh: uint,
    current-charge: uint,
    charge-cycles: uint,
    installation-date: uint,
    warranty-expires: uint,
    status: (string-ascii 20)
  }
)

(define-map energy-transactions
  { system-id: uint, transaction-id: uint }
  {
    transaction-type: (string-ascii 20),
    energy-amount: uint,
    timestamp: uint,
    grid-connection: bool,
    price-per-kwh: uint
  }
)

(define-data-var system-nonce uint u0)

(define-public (install-system
  (location (string-ascii 100))
  (capacity uint)
  (warranty-period uint)
)
  (let ((system-id (var-get system-nonce)))
    (map-set battery-systems
      { system-id: system-id }
      {
        owner: tx-sender,
        location: location,
        capacity-kwh: capacity,
        current-charge: u0,
        charge-cycles: u0,
        installation-date: stacks-block-height,
        warranty-expires: (+ stacks-block-height warranty-period),
        status: "active"
      }
    )
    (var-set system-nonce (+ system-id u1))
    (ok system-id)
  )
)

(define-public (charge-battery (system-id uint) (amount uint) (transaction-id uint))
  (let ((system (unwrap! (map-get? battery-systems { system-id: system-id }) ERR-UNIT-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner system)) ERR-NOT-AUTHORIZED)
    (asserts! (<= (+ (get current-charge system) amount) (get capacity-kwh system)) ERR-INSUFFICIENT-CAPACITY)
    (map-set energy-transactions
      { system-id: system-id, transaction-id: transaction-id }
      {
        transaction-type: "charge",
        energy-amount: amount,
        timestamp: stacks-block-height,
        grid-connection: true,
        price-per-kwh: u0
      }
    )
    (ok (map-set battery-systems
      { system-id: system-id }
      (merge system { current-charge: (+ (get current-charge system) amount) })
    ))
  )
)

(define-public (discharge-battery (system-id uint) (amount uint) (transaction-id uint))
  (let ((system (unwrap! (map-get? battery-systems { system-id: system-id }) ERR-UNIT-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner system)) ERR-NOT-AUTHORIZED)
    (asserts! (>= (get current-charge system) amount) ERR-INSUFFICIENT-CAPACITY)
    (map-set energy-transactions
      { system-id: system-id, transaction-id: transaction-id }
      {
        transaction-type: "discharge",
        energy-amount: amount,
        timestamp: stacks-block-height,
        grid-connection: true,
        price-per-kwh: u0
      }
    )
    (ok (map-set battery-systems
      { system-id: system-id }
      (merge system { 
        current-charge: (- (get current-charge system) amount),
        charge-cycles: (+ (get charge-cycles system) u1)
      })
    ))
  )
)

(define-read-only (get-system-info (system-id uint))
  (map-get? battery-systems { system-id: system-id })
)

(define-read-only (get-transaction (system-id uint) (transaction-id uint))
  (map-get? energy-transactions { system-id: system-id, transaction-id: transaction-id })
)

(define-public (update-status (system-id uint) (new-status (string-ascii 20)))
  (let ((system (unwrap! (map-get? battery-systems { system-id: system-id }) ERR-UNIT-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner system)) ERR-NOT-AUTHORIZED)
    (ok (map-set battery-systems
      { system-id: system-id }
      (merge system { status: new-status })
    ))
  )
)

(define-public (update-current-charge (system-id uint) (new-charge uint))
  (let ((system (unwrap! (map-get? battery-systems { system-id: system-id }) ERR-UNIT-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner system)) ERR-NOT-AUTHORIZED)
    (ok (map-set battery-systems
      { system-id: system-id }
      (merge system { current-charge: new-charge })
    ))
  )
)
