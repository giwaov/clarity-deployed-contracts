(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map lng-facilities
  uint
  {
    operator: principal,
    location: (string-ascii 128),
    liquefaction-capacity: uint,
    storage-capacity: uint,
    facility-type: (string-ascii 32),
    operational: bool
  })

(define-map lng-shipments
  uint
  {
    facility-id: uint,
    volume-tonnes: uint,
    origin: (string-ascii 128),
    destination: (string-ascii 128),
    shipment-date: uint,
    status: (string-ascii 32)
  })

(define-data-var next-facility-id uint u0)
(define-data-var next-lng-shipment-id uint u0)

(define-read-only (get-facility (facility-id uint))
  (ok (map-get? lng-facilities facility-id)))

(define-public (register-facility (location (string-ascii 128)) (liq-capacity uint) (storage uint) (type (string-ascii 32)))
  (let ((facility-id (var-get next-facility-id)))
    (map-set lng-facilities facility-id
      {operator: tx-sender, location: location, liquefaction-capacity: liq-capacity,
       storage-capacity: storage, facility-type: type, operational: true})
    (var-set next-facility-id (+ facility-id u1))
    (ok facility-id)))

(define-public (create-lng-shipment (facility-id uint) (volume uint) (origin (string-ascii 128)) (dest (string-ascii 128)))
  (let ((shipment-id (var-get next-lng-shipment-id)))
    (asserts! (is-some (map-get? lng-facilities facility-id)) err-not-found)
    (map-set lng-shipments shipment-id
      {facility-id: facility-id, volume-tonnes: volume, origin: origin,
       destination: dest, shipment-date: stacks-block-height, status: "in-transit"})
    (var-set next-lng-shipment-id (+ shipment-id u1))
    (ok shipment-id)))

(define-public (update-shipment-status (shipment-id uint) (status (string-ascii 32)))
  (let ((shipment (unwrap! (map-get? lng-shipments shipment-id) err-not-found)))
    (ok (map-set lng-shipments shipment-id (merge shipment {status: status})))))
