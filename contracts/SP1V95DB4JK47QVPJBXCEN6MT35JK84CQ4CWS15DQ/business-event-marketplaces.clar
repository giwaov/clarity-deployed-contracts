(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-registration-closed (err u102))
(define-constant err-not-authorized (err u103))

(define-map business-events
  uint
  {
    organizer: principal,
    event-name: (string-ascii 128),
    industry: (string-ascii 64),
    event-type: (string-ascii 64),
    start-block: uint,
    max-attendees: uint,
    registered-count: uint,
    registration-fee: uint,
    requires-approval: bool
  })

(define-map registrations
  {event-id: uint, attendee: principal}
  {approved: bool, paid: bool, checked-in: bool})

(define-data-var next-event-id uint u0)

(define-read-only (get-event (event-id uint))
  (ok (map-get? business-events event-id)))

(define-read-only (get-registration (event-id uint) (attendee principal))
  (ok (map-get? registrations {event-id: event-id, attendee: attendee})))

(define-public (create-event (name (string-ascii 128)) (industry (string-ascii 64)) (type (string-ascii 64)) (start uint) (max uint) (fee uint) (approval bool))
  (let ((event-id (var-get next-event-id)))
    (map-set business-events event-id
      {organizer: tx-sender, event-name: name, industry: industry, event-type: type,
       start-block: start, max-attendees: max, registered-count: u0,
       registration-fee: fee, requires-approval: approval})
    (var-set next-event-id (+ event-id u1))
    (ok event-id)))

(define-public (register (event-id uint))
  (let ((event (unwrap! (map-get? business-events event-id) err-not-found)))
    (asserts! (< (get registered-count event) (get max-attendees event)) err-registration-closed)
    (try! (stx-transfer? (get registration-fee event) tx-sender (get organizer event)))
    (map-set registrations {event-id: event-id, attendee: tx-sender}
      {approved: (not (get requires-approval event)), paid: true, checked-in: false})
    (map-set business-events event-id
      (merge event {registered-count: (+ (get registered-count event) u1)}))
    (ok true)))

(define-public (approve-attendee (event-id uint) (attendee principal))
  (let ((event (unwrap! (map-get? business-events event-id) err-not-found))
        (registration (unwrap! (map-get? registrations {event-id: event-id, attendee: attendee}) err-not-found)))
    (asserts! (is-eq tx-sender (get organizer event)) err-owner-only)
    (ok (map-set registrations {event-id: event-id, attendee: attendee}
      (merge registration {approved: true})))))

(define-public (check-in (event-id uint))
  (let ((registration (unwrap! (map-get? registrations {event-id: event-id, attendee: tx-sender}) err-not-found)))
    (asserts! (get approved registration) err-not-authorized)
    (ok (map-set registrations {event-id: event-id, attendee: tx-sender}
      (merge registration {checked-in: true})))))
