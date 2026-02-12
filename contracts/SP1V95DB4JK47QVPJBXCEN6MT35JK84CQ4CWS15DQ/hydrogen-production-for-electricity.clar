(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map hydrogen-plants
  uint
  {
    operator: principal,
    location: (string-ascii 128),
    production-method: (string-ascii 64),
    capacity-kg-per-day: uint,
    power-output-mw: uint,
    operational: bool
  })

(define-map electricity-generation
  uint
  {
    plant-id: uint,
    hydrogen-consumed-kg: uint,
    power-generated-mwh: uint,
    efficiency: uint,
    timestamp: uint
  })

(define-data-var next-plant-id uint u0)
(define-data-var next-generation-id uint u0)

(define-read-only (get-plant (plant-id uint))
  (ok (map-get? hydrogen-plants plant-id)))

(define-public (register-plant (location (string-ascii 128)) (method (string-ascii 64)) (capacity uint) (output uint))
  (let ((plant-id (var-get next-plant-id)))
    (map-set hydrogen-plants plant-id
      {operator: tx-sender, location: location, production-method: method,
       capacity-kg-per-day: capacity, power-output-mw: output, operational: true})
    (var-set next-plant-id (+ plant-id u1))
    (ok plant-id)))

(define-public (log-generation (plant-id uint) (hydrogen-used uint) (power uint) (efficiency uint))
  (let ((gen-id (var-get next-generation-id)))
    (asserts! (is-some (map-get? hydrogen-plants plant-id)) err-not-found)
    (map-set electricity-generation gen-id
      {plant-id: plant-id, hydrogen-consumed-kg: hydrogen-used,
       power-generated-mwh: power, efficiency: efficiency, timestamp: stacks-block-height})
    (var-set next-generation-id (+ gen-id u1))
    (ok gen-id)))
