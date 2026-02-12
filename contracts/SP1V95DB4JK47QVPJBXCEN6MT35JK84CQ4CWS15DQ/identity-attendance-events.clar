(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-not-verified (err u102))
(define-constant err-capacity-full (err u103))

(define-map identity-verified-events
  uint
  {
    organizer: principal,
    event-name: (string-ascii 128),
    verification-level: (string-ascii 32),
    date: uint,
    location: (string-ascii 256),
    max-attendees: uint,
    verified-attendees: uint,
    ticket-price: uint
  })

(define-map verified-identities
  principal
  {
    full-name: (string-ascii 128),
    verification-method: (string-ascii 64),
    verification-level: (string-ascii 32),
    verified-at: uint,
    issuer: principal
  })

(define-map attendance-records
  {event-id: uint, attendee: principal}
  {ticket-purchased: uint, check-in-time: uint, verified-onsite: bool})

(define-data-var next-event-id uint u0)

(define-read-only (get-event (event-id uint))
  (ok (map-get? identity-verified-events event-id)))

(define-read-only (get-identity (user principal))
  (ok (map-get? verified-identities user)))

(define-public (verify-identity (user principal) (name (string-ascii 128)) (method (string-ascii 64)) (level (string-ascii 32)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set verified-identities user
      {full-name: name, verification-method: method, verification-level: level,
       verified-at: stacks-block-height, issuer: tx-sender}))))

(define-public (create-verified-event (name (string-ascii 128)) (ver-level (string-ascii 32)) (date uint) (location (string-ascii 256)) (max uint) (price uint))
  (let ((event-id (var-get next-event-id)))
    (map-set identity-verified-events event-id
      {organizer: tx-sender, event-name: name, verification-level: ver-level,
       date: date, location: location, max-attendees: max, verified-attendees: u0,
       ticket-price: price})
    (var-set next-event-id (+ event-id u1))
    (ok event-id)))

(define-public (purchase-verified-ticket (event-id uint))
  (let ((event (unwrap! (map-get? identity-verified-events event-id) err-not-found))
        (identity (unwrap! (map-get? verified-identities tx-sender) err-not-verified)))
    (asserts! (is-eq (get verification-level identity) (get verification-level event)) err-not-verified)
    (asserts! (< (get verified-attendees event) (get max-attendees event)) err-capacity-full)
    (try! (stx-transfer? (get ticket-price event) tx-sender (get organizer event)))
    (map-set attendance-records {event-id: event-id, attendee: tx-sender}
      {ticket-purchased: stacks-block-height, check-in-time: u0, verified-onsite: false})
    (ok (map-set identity-verified-events event-id
      (merge event {verified-attendees: (+ (get verified-attendees event) u1)})))))

(define-public (check-in-attendee (event-id uint))
  (let ((record (unwrap! (map-get? attendance-records {event-id: event-id, attendee: tx-sender}) err-not-found)))
    (ok (map-set attendance-records {event-id: event-id, attendee: tx-sender}
      (merge record {check-in-time: stacks-block-height, verified-onsite: true})))))
