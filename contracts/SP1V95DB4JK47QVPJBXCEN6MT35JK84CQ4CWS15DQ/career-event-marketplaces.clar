(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-full (err u102))
(define-constant err-invalid-career-stage (err u103))

(define-map career-events
  uint
  {
    organizer: principal,
    event-name: (string-ascii 128),
    career-stage: (string-ascii 64),
    industry: (string-ascii 64),
    event-type: (string-ascii 64),
    date: uint,
    max-participants: uint,
    registered: uint,
    price: uint
  })

(define-map participant-registrations
  {event-id: uint, participant: principal}
  {career-level: (string-ascii 64), resume-submitted: bool, attended: bool})

(define-map networking-connections
  {event-id: uint, user1: principal, user2: principal}
  {connected-at: uint})

(define-data-var next-event-id uint u0)

(define-read-only (get-event (event-id uint))
  (ok (map-get? career-events event-id)))

(define-read-only (get-registration (event-id uint) (participant principal))
  (ok (map-get? participant-registrations {event-id: event-id, participant: participant})))

(define-public (create-event (name (string-ascii 128)) (stage (string-ascii 64)) (industry (string-ascii 64)) (type (string-ascii 64)) (date uint) (max uint) (price uint))
  (let ((event-id (var-get next-event-id)))
    (map-set career-events event-id
      {organizer: tx-sender, event-name: name, career-stage: stage, industry: industry,
       event-type: type, date: date, max-participants: max, registered: u0, price: price})
    (var-set next-event-id (+ event-id u1))
    (ok event-id)))

(define-public (register-participant (event-id uint) (level (string-ascii 64)))
  (let ((event (unwrap! (map-get? career-events event-id) err-not-found)))
    (asserts! (< (get registered event) (get max-participants event)) err-full)
    (try! (stx-transfer? (get price event) tx-sender (get organizer event)))
    (map-set participant-registrations {event-id: event-id, participant: tx-sender}
      {career-level: level, resume-submitted: false, attended: false})
    (ok (map-set career-events event-id (merge event {registered: (+ (get registered event) u1)})))))

(define-public (submit-resume (event-id uint))
  (let ((registration (unwrap! (map-get? participant-registrations {event-id: event-id, participant: tx-sender}) err-not-found)))
    (ok (map-set participant-registrations {event-id: event-id, participant: tx-sender}
      (merge registration {resume-submitted: true})))))

(define-public (mark-attendance (event-id uint) (participant principal))
  (let ((event (unwrap! (map-get? career-events event-id) err-not-found))
        (registration (unwrap! (map-get? participant-registrations {event-id: event-id, participant: participant}) err-not-found)))
    (asserts! (is-eq tx-sender (get organizer event)) err-owner-only)
    (ok (map-set participant-registrations {event-id: event-id, participant: participant}
      (merge registration {attended: true})))))

(define-public (connect-attendees (event-id uint) (other-user principal))
  (begin
    (asserts! (is-some (map-get? participant-registrations {event-id: event-id, participant: tx-sender})) err-not-found)
    (asserts! (is-some (map-get? participant-registrations {event-id: event-id, participant: other-user})) err-not-found)
    (ok (map-set networking-connections {event-id: event-id, user1: tx-sender, user2: other-user}
      {connected-at: stacks-block-height}))))
