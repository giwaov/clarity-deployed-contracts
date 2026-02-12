(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-gate-occupied (err u102))
(define-constant err-runway-busy (err u103))

(define-map airport-gates
  {airport: (string-ascii 8), gate: (string-ascii 8)}
  {occupied: bool, flight-number: (string-ascii 32), scheduled-time: uint})

(define-map runways
  {airport: (string-ascii 8), runway: (string-ascii 8)}
  {active: bool, current-flight: (string-ascii 32), operation-type: (string-ascii 16)})

(define-map flight-schedules
  uint
  {
    flight-number: (string-ascii 32),
    airport: (string-ascii 8),
    scheduled-time: uint,
    actual-time: uint,
    gate: (string-ascii 8),
    status: (string-ascii 32)
  })

(define-data-var next-schedule-id uint u0)

(define-read-only (get-gate (airport (string-ascii 8)) (gate (string-ascii 8)))
  (ok (map-get? airport-gates {airport: airport, gate: gate})))

(define-read-only (get-schedule (schedule-id uint))
  (ok (map-get? flight-schedules schedule-id)))

(define-public (assign-gate (airport (string-ascii 8)) (gate (string-ascii 8)) (flight (string-ascii 32)) (time uint))
  (let ((gate-info (default-to {occupied: false, flight-number: "", scheduled-time: u0}
                               (map-get? airport-gates {airport: airport, gate: gate}))))
    (asserts! (not (get occupied gate-info)) err-gate-occupied)
    (ok (map-set airport-gates {airport: airport, gate: gate}
      {occupied: true, flight-number: flight, scheduled-time: time}))))

(define-public (release-gate (airport (string-ascii 8)) (gate (string-ascii 8)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set airport-gates {airport: airport, gate: gate}
      {occupied: false, flight-number: "", scheduled-time: u0}))))

(define-public (request-runway (airport (string-ascii 8)) (runway (string-ascii 8)) (flight (string-ascii 32)) (op-type (string-ascii 16)))
  (let ((runway-info (default-to {active: false, current-flight: "", operation-type: ""}
                                 (map-get? runways {airport: airport, runway: runway}))))
    (asserts! (not (get active runway-info)) err-runway-busy)
    (ok (map-set runways {airport: airport, runway: runway}
      {active: true, current-flight: flight, operation-type: op-type}))))

(define-public (clear-runway (airport (string-ascii 8)) (runway (string-ascii 8)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set runways {airport: airport, runway: runway}
      {active: false, current-flight: "", operation-type: ""}))))
