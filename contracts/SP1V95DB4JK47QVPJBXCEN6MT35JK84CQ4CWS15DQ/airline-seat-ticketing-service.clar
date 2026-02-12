(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-SEAT-NOT-AVAILABLE (err u101))
(define-constant ERR-BOOKING-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-CHECKED-IN (err u103))

(define-map flights
  { flight-id: (string-ascii 20) }
  {
    airline: (string-ascii 50),
    departure: (string-ascii 50),
    destination: (string-ascii 50),
    departure-time: uint,
    total-seats: uint,
    available-seats: uint,
    operator: principal
  }
)

(define-map seat-bookings
  { flight-id: (string-ascii 20), seat-number: (string-ascii 10) }
  {
    passenger: principal,
    passenger-name: (string-ascii 100),
    booking-time: uint,
    checked-in: bool,
    booking-id: uint
  }
)

(define-data-var booking-nonce uint u0)

(define-public (create-flight
  (flight-id (string-ascii 20))
  (airline (string-ascii 50))
  (departure (string-ascii 50))
  (destination (string-ascii 50))
  (departure-time uint)
  (total-seats uint)
)
  (ok (map-set flights
    { flight-id: flight-id }
    {
      airline: airline,
      departure: departure,
      destination: destination,
      departure-time: departure-time,
      total-seats: total-seats,
      available-seats: total-seats,
      operator: tx-sender
    }
  ))
)

(define-public (book-seat
  (flight-id (string-ascii 20))
  (seat-number (string-ascii 10))
  (passenger-name (string-ascii 100))
)
  (let (
    (flight (unwrap! (map-get? flights { flight-id: flight-id }) ERR-SEAT-NOT-AVAILABLE))
    (booking-id (var-get booking-nonce))
  )
    (asserts! (> (get available-seats flight) u0) ERR-SEAT-NOT-AVAILABLE)
    (map-set seat-bookings
      { flight-id: flight-id, seat-number: seat-number }
      {
        passenger: tx-sender,
        passenger-name: passenger-name,
        booking-time: stacks-block-height,
        checked-in: false,
        booking-id: booking-id
      }
    )
    (map-set flights
      { flight-id: flight-id }
      (merge flight { available-seats: (- (get available-seats flight) u1) })
    )
    (var-set booking-nonce (+ booking-id u1))
    (ok booking-id)
  )
)

(define-public (check-in (flight-id (string-ascii 20)) (seat-number (string-ascii 10)))
  (let (
    (booking (unwrap! (map-get? seat-bookings { flight-id: flight-id, seat-number: seat-number }) ERR-BOOKING-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get passenger booking)) ERR-NOT-AUTHORIZED)
    (asserts! (not (get checked-in booking)) ERR-ALREADY-CHECKED-IN)
    (ok (map-set seat-bookings
      { flight-id: flight-id, seat-number: seat-number }
      (merge booking { checked-in: true })
    ))
  )
)

(define-read-only (get-flight-info (flight-id (string-ascii 20)))
  (map-get? flights { flight-id: flight-id })
)

(define-read-only (get-booking (flight-id (string-ascii 20)) (seat-number (string-ascii 10)))
  (map-get? seat-bookings { flight-id: flight-id, seat-number: seat-number })
)

(define-public (cancel-booking (flight-id (string-ascii 20)) (seat-number (string-ascii 10)))
  (let (
    (booking (unwrap! (map-get? seat-bookings { flight-id: flight-id, seat-number: seat-number }) ERR-BOOKING-NOT-FOUND))
    (flight (unwrap! (map-get? flights { flight-id: flight-id }) ERR-SEAT-NOT-AVAILABLE))
  )
    (asserts! (is-eq tx-sender (get passenger booking)) ERR-NOT-AUTHORIZED)
    (map-delete seat-bookings { flight-id: flight-id, seat-number: seat-number })
    (ok (map-set flights
      { flight-id: flight-id }
      (merge flight { available-seats: (+ (get available-seats flight) u1) })
    ))
  )
)
