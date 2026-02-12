(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u104))
(define-constant err-grid-offline (err u120))

(define-data-var grid-nonce uint u0)

(define-map microgrids
  uint
  {
    operator: principal,
    grid-capacity: uint,
    current-load: uint,
    energy-sources: uint,
    battery-capacity: uint,
    stored-energy: uint,
    location-hash: (buff 32),
    islanded: bool,
    active: bool,
    created-block: uint
  }
)

(define-map grid-participants
  {grid-id: uint, participant: principal}
  {
    contribution: uint,
    consumption: uint,
    battery-share: uint,
    joined-block: uint
  }
)

(define-map energy-transactions
  {grid-id: uint, tx-id: uint}
  {
    from: principal,
    to: principal,
    amount: uint,
    price: uint,
    block: uint
  }
)

(define-map tx-counter uint uint)
(define-map operator-grids principal (list 10 uint))

(define-public (create-microgrid (capacity uint) (battery uint) (location (buff 32)))
  (let
    (
      (grid-id (+ (var-get grid-nonce) u1))
    )
    (asserts! (> capacity u0) err-invalid-amount)
    (map-set microgrids grid-id {
      operator: tx-sender,
      grid-capacity: capacity,
      current-load: u0,
      energy-sources: u0,
      battery-capacity: battery,
      stored-energy: u0,
      location-hash: location,
      islanded: false,
      active: true,
      created-block: stacks-block-height
    })
    (map-set tx-counter grid-id u0)
    (map-set operator-grids tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? operator-grids tx-sender)) grid-id) u10)))
    (var-set grid-nonce grid-id)
    (ok grid-id)
  )
)

(define-public (join-grid (grid-id uint) (battery-share uint))
  (let
    (
      (grid (unwrap! (map-get? microgrids grid-id) err-not-found))
    )
    (asserts! (get active grid) err-grid-offline)
    (map-set grid-participants {grid-id: grid-id, participant: tx-sender} {
      contribution: u0,
      consumption: u0,
      battery-share: battery-share,
      joined-block: stacks-block-height
    })
    (ok true)
  )
)

(define-public (contribute-energy (grid-id uint) (amount uint))
  (let
    (
      (grid (unwrap! (map-get? microgrids grid-id) err-not-found))
      (participant (unwrap! (map-get? grid-participants {grid-id: grid-id, participant: tx-sender}) err-not-found))
      (new-sources (+ (get energy-sources grid) amount))
    )
    (asserts! (get active grid) err-grid-offline)
    (map-set grid-participants {grid-id: grid-id, participant: tx-sender}
      (merge participant {contribution: (+ (get contribution participant) amount)}))
    (map-set microgrids grid-id (merge grid {energy-sources: new-sources}))
    (ok true)
  )
)

(define-public (consume-energy (grid-id uint) (amount uint) (payment uint))
  (let
    (
      (grid (unwrap! (map-get? microgrids grid-id) err-not-found))
      (participant (unwrap! (map-get? grid-participants {grid-id: grid-id, participant: tx-sender}) err-not-found))
      (new-load (+ (get current-load grid) amount))
    )
    (asserts! (get active grid) err-grid-offline)
    (asserts! (<= new-load (get grid-capacity grid)) err-invalid-amount)
    (try! (stx-transfer? payment tx-sender (get operator grid)))
    (map-set grid-participants {grid-id: grid-id, participant: tx-sender}
      (merge participant {consumption: (+ (get consumption participant) amount)}))
    (map-set microgrids grid-id (merge grid {current-load: new-load}))
    (ok true)
  )
)

(define-public (store-in-battery (grid-id uint) (amount uint))
  (let
    (
      (grid (unwrap! (map-get? microgrids grid-id) err-not-found))
      (new-stored (+ (get stored-energy grid) amount))
    )
    (asserts! (is-eq tx-sender (get operator grid)) err-unauthorized)
    (asserts! (<= new-stored (get battery-capacity grid)) err-invalid-amount)
    (map-set microgrids grid-id (merge grid {stored-energy: new-stored}))
    (ok true)
  )
)

(define-public (toggle-island-mode (grid-id uint))
  (let
    (
      (grid (unwrap! (map-get? microgrids grid-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get operator grid)) err-unauthorized)
    (map-set microgrids grid-id (merge grid {islanded: (not (get islanded grid))}))
    (ok true)
  )
)

(define-read-only (get-grid (grid-id uint))
  (ok (map-get? microgrids grid-id))
)

(define-read-only (get-participant (grid-id uint) (participant principal))
  (ok (map-get? grid-participants {grid-id: grid-id, participant: participant}))
)

(define-read-only (get-operator-grids (operator principal))
  (ok (map-get? operator-grids operator))
)

(define-read-only (calculate-grid-efficiency (grid-id uint))
  (let
    (
      (grid (unwrap-panic (map-get? microgrids grid-id)))
      (capacity (get grid-capacity grid))
      (load (get current-load grid))
    )
    (if (> capacity u0)
      (ok (/ (* load u100) capacity))
      (ok u0)
    )
  )
)

(define-read-only (get-available-capacity (grid-id uint))
  (let
    (
      (grid (unwrap-panic (map-get? microgrids grid-id)))
    )
    (ok (- (get grid-capacity grid) (get current-load grid)))
  )
)
