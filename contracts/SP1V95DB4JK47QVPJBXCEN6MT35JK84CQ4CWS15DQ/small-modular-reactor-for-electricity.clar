(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map smr-reactors
  uint
  {
    operator: principal,
    location: (string-ascii 128),
    reactor-model: (string-ascii 64),
    capacity-mw: uint,
    fuel-type: (string-ascii 32),
    commissioned-date: uint,
    licensed: bool,
    operational: bool
  })

(define-map power-generation-smr
  uint
  {
    reactor-id: uint,
    power-output-mwh: uint,
    fuel-consumed: uint,
    efficiency: uint,
    timestamp: uint
  })

(define-data-var next-reactor-id uint u0)
(define-data-var next-gen-id uint u0)

(define-read-only (get-reactor (reactor-id uint))
  (ok (map-get? smr-reactors reactor-id)))

(define-public (register-smr (location (string-ascii 128)) (model (string-ascii 64)) (capacity uint) (fuel (string-ascii 32)))
  (let ((reactor-id (var-get next-reactor-id)))
    (map-set smr-reactors reactor-id
      {operator: tx-sender, location: location, reactor-model: model,
       capacity-mw: capacity, fuel-type: fuel, commissioned-date: stacks-block-height,
       licensed: false, operational: false})
    (var-set next-reactor-id (+ reactor-id u1))
    (ok reactor-id)))

(define-public (license-smr (reactor-id uint))
  (let ((reactor (unwrap! (map-get? smr-reactors reactor-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set smr-reactors reactor-id (merge reactor {licensed: true, operational: true})))))

(define-public (log-power-output (reactor-id uint) (power uint) (fuel uint) (efficiency uint))
  (let ((gen-id (var-get next-gen-id)))
    (asserts! (is-some (map-get? smr-reactors reactor-id)) err-not-found)
    (map-set power-generation-smr gen-id
      {reactor-id: reactor-id, power-output-mwh: power, fuel-consumed: fuel,
       efficiency: efficiency, timestamp: stacks-block-height})
    (var-set next-gen-id (+ gen-id u1))
    (ok gen-id)))
