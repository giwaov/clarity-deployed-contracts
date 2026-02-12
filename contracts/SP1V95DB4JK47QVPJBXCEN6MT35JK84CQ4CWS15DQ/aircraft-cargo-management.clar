(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-invalid-weight (err u102))
(define-constant err-capacity-exceeded (err u103))

(define-map cargo-shipments
  uint
  {
    shipper: principal,
    flight-number: (string-ascii 32),
    origin: (string-ascii 64),
    destination: (string-ascii 64),
    weight-kg: uint,
    volume-m3: uint,
    cargo-type: (string-ascii 64),
    scheduled-departure: uint,
    status: (string-ascii 32),
    loaded: bool
  })

(define-map aircraft-cargo-capacity
  (string-ascii 32)
  {max-weight: uint, max-volume: uint, current-weight: uint, current-volume: uint})

(define-data-var next-shipment-id uint u0)

(define-read-only (get-shipment (shipment-id uint))
  (ok (map-get? cargo-shipments shipment-id)))

(define-public (register-shipment (flight (string-ascii 32)) (origin (string-ascii 64)) (dest (string-ascii 64)) (weight uint) (volume uint) (type (string-ascii 64)) (departure uint))
  (let ((shipment-id (var-get next-shipment-id))
        (capacity (default-to {max-weight: u50000, max-volume: u500, current-weight: u0, current-volume: u0}
                             (map-get? aircraft-cargo-capacity flight))))
    (asserts! (<= (+ (get current-weight capacity) weight) (get max-weight capacity)) err-capacity-exceeded)
    (map-set cargo-shipments shipment-id
      {shipper: tx-sender, flight-number: flight, origin: origin, destination: dest,
       weight-kg: weight, volume-m3: volume, cargo-type: type,
       scheduled-departure: departure, status: "pending", loaded: false})
    (var-set next-shipment-id (+ shipment-id u1))
    (ok shipment-id)))

(define-public (load-cargo (shipment-id uint))
  (let ((shipment (unwrap! (map-get? cargo-shipments shipment-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set cargo-shipments shipment-id (merge shipment {loaded: true, status: "loaded"})))))

(define-public (update-status (shipment-id uint) (new-status (string-ascii 32)))
  (let ((shipment (unwrap! (map-get? cargo-shipments shipment-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set cargo-shipments shipment-id (merge shipment {status: new-status})))))
