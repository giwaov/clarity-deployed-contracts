(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map lng-carriers
  (string-ascii 64)
  {
    operator: principal,
    capacity-cubic-meters: uint,
    carrier-type: (string-ascii 32),
    build-year: uint,
    certified: bool,
    active: bool
  })

(define-map lng-voyages
  uint
  {
    carrier-id: (string-ascii 64),
    loading-port: (string-ascii 128),
    discharge-port: (string-ascii 128),
    cargo-volume: uint,
    departure: uint,
    eta: uint,
    status: (string-ascii 32)
  })

(define-data-var next-voyage-id uint u0)

(define-read-only (get-carrier (carrier-id (string-ascii 64)))
  (ok (map-get? lng-carriers carrier-id)))

(define-public (register-carrier (carrier-id (string-ascii 64)) (capacity uint) (type (string-ascii 32)) (year uint))
  (begin
    (map-set lng-carriers carrier-id
      {operator: tx-sender, capacity-cubic-meters: capacity, carrier-type: type,
       build-year: year, certified: false, active: true})
    (ok true)))

(define-public (certify-carrier (carrier-id (string-ascii 64)))
  (let ((carrier (unwrap! (map-get? lng-carriers carrier-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set lng-carriers carrier-id (merge carrier {certified: true})))))

(define-public (schedule-voyage (carrier-id (string-ascii 64)) (loading (string-ascii 128)) (discharge (string-ascii 128)) (volume uint) (eta uint))
  (let ((voyage-id (var-get next-voyage-id)))
    (map-set lng-voyages voyage-id
      {carrier-id: carrier-id, loading-port: loading, discharge-port: discharge,
       cargo-volume: volume, departure: stacks-block-height, eta: eta, status: "scheduled"})
    (var-set next-voyage-id (+ voyage-id u1))
    (ok voyage-id)))
