(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map nuclear-plants
  uint
  {
    operator: principal,
    location: (string-ascii 128),
    reactor-type: (string-ascii 64),
    capacity-mw: uint,
    commissioned: uint,
    licensed: bool,
    operational: bool
  })

(define-map power-production
  uint
  {
    plant-id: uint,
    energy-produced-mwh: uint,
    fuel-consumed-kg: uint,
    capacity-factor: uint,
    timestamp: uint
  })

(define-data-var next-plant-id uint u0)
(define-data-var next-production-id uint u0)

(define-read-only (get-plant (plant-id uint))
  (ok (map-get? nuclear-plants plant-id)))

(define-public (register-plant (location (string-ascii 128)) (reactor (string-ascii 64)) (capacity uint))
  (let ((plant-id (var-get next-plant-id)))
    (map-set nuclear-plants plant-id
      {operator: tx-sender, location: location, reactor-type: reactor,
       capacity-mw: capacity, commissioned: stacks-block-height, licensed: false, operational: false})
    (var-set next-plant-id (+ plant-id u1))
    (ok plant-id)))

(define-public (license-plant (plant-id uint))
  (let ((plant (unwrap! (map-get? nuclear-plants plant-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set nuclear-plants plant-id (merge plant {licensed: true, operational: true})))))

(define-public (record-production (plant-id uint) (energy uint) (fuel uint) (capacity-factor uint))
  (let ((production-id (var-get next-production-id)))
    (asserts! (is-some (map-get? nuclear-plants plant-id)) err-not-found)
    (map-set power-production production-id
      {plant-id: plant-id, energy-produced-mwh: energy, fuel-consumed-kg: fuel,
       capacity-factor: capacity-factor, timestamp: stacks-block-height})
    (var-set next-production-id (+ production-id u1))
    (ok production-id)))
