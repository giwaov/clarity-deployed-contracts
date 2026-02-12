(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map oil-tankers
  (string-ascii 64)
  {
    operator: principal,
    capacity-barrels: uint,
    current-cargo: uint,
    tanker-type: (string-ascii 32),
    registered: bool,
    active: bool
  })

(define-map tanker-voyages
  uint
  {
    tanker-id: (string-ascii 64),
    departure-port: (string-ascii 128),
    arrival-port: (string-ascii 128),
    cargo-volume: uint,
    departure-date: uint,
    estimated-arrival: uint,
    status: (string-ascii 32)
  })

(define-data-var next-voyage-id uint u0)

(define-read-only (get-tanker (tanker-id (string-ascii 64)))
  (ok (map-get? oil-tankers tanker-id)))

(define-public (register-tanker (tanker-id (string-ascii 64)) (capacity uint) (type (string-ascii 32)))
  (begin
    (map-set oil-tankers tanker-id
      {operator: tx-sender, capacity-barrels: capacity, current-cargo: u0,
       tanker-type: type, registered: true, active: true})
    (ok true)))

(define-public (schedule-voyage (tanker-id (string-ascii 64)) (dep-port (string-ascii 128)) (arr-port (string-ascii 128)) (cargo uint) (eta uint))
  (let ((voyage-id (var-get next-voyage-id)))
    (map-set tanker-voyages voyage-id
      {tanker-id: tanker-id, departure-port: dep-port, arrival-port: arr-port,
       cargo-volume: cargo, departure-date: stacks-block-height, estimated-arrival: eta, status: "scheduled"})
    (var-set next-voyage-id (+ voyage-id u1))
    (ok voyage-id)))

(define-public (update-voyage-status (voyage-id uint) (status (string-ascii 32)))
  (let ((voyage (unwrap! (map-get? tanker-voyages voyage-id) err-not-found)))
    (ok (map-set tanker-voyages voyage-id (merge voyage {status: status})))))
