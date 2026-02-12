(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-full (err u102))
(define-constant err-not-organizer (err u103))

(define-map tech-meetups
  uint
  {
    organizer: principal,
    meetup-title: (string-ascii 128),
    tech-stack: (string-ascii 64),
    skill-level: (string-ascii 32),
    venue: (string-ascii 256),
    scheduled-block: uint,
    capacity: uint,
    rsvps: uint,
    is-free: bool,
    ticket-price: uint
  })

(define-map rsvp-list
  {meetup-id: uint, attendee: principal}
  {rsvp-at: uint, checked-in: bool, speaker: bool})

(define-map organizer-profiles
  principal
  {
    organization: (string-ascii 128),
    total-events: uint,
    verified: bool
  })

(define-data-var next-meetup-id uint u0)

(define-read-only (get-meetup (meetup-id uint))
  (ok (map-get? tech-meetups meetup-id)))

(define-read-only (get-rsvp (meetup-id uint) (attendee principal))
  (ok (map-get? rsvp-list {meetup-id: meetup-id, attendee: attendee})))

(define-public (register-organizer (org (string-ascii 128)))
  (begin
    (map-set organizer-profiles tx-sender
      {organization: org, total-events: u0, verified: false})
    (ok true)))

(define-public (create-meetup (title (string-ascii 128)) (stack (string-ascii 64)) (level (string-ascii 32)) (venue (string-ascii 256)) (scheduled uint) (capacity uint) (free bool) (price uint))
  (let ((meetup-id (var-get next-meetup-id))
        (profile (default-to {organization: "", total-events: u0, verified: false}
                            (map-get? organizer-profiles tx-sender))))
    (map-set tech-meetups meetup-id
      {organizer: tx-sender, meetup-title: title, tech-stack: stack, skill-level: level,
       venue: venue, scheduled-block: scheduled, capacity: capacity, rsvps: u0,
       is-free: free, ticket-price: price})
    (map-set organizer-profiles tx-sender
      (merge profile {total-events: (+ (get total-events profile) u1)}))
    (var-set next-meetup-id (+ meetup-id u1))
    (ok meetup-id)))

(define-public (rsvp-meetup (meetup-id uint))
  (let ((meetup (unwrap! (map-get? tech-meetups meetup-id) err-not-found)))
    (asserts! (< (get rsvps meetup) (get capacity meetup)) err-full)
    (if (not (get is-free meetup))
      (try! (stx-transfer? (get ticket-price meetup) tx-sender (get organizer meetup)))
      true)
    (map-set rsvp-list {meetup-id: meetup-id, attendee: tx-sender}
      {rsvp-at: stacks-block-height, checked-in: false, speaker: false})
    (ok (map-set tech-meetups meetup-id (merge meetup {rsvps: (+ (get rsvps meetup) u1)})))))

(define-public (check-in (meetup-id uint))
  (let ((rsvp (unwrap! (map-get? rsvp-list {meetup-id: meetup-id, attendee: tx-sender}) err-not-found)))
    (ok (map-set rsvp-list {meetup-id: meetup-id, attendee: tx-sender}
      (merge rsvp {checked-in: true})))))

(define-public (designate-speaker (meetup-id uint) (attendee principal))
  (let ((meetup (unwrap! (map-get? tech-meetups meetup-id) err-not-found))
        (rsvp (unwrap! (map-get? rsvp-list {meetup-id: meetup-id, attendee: attendee}) err-not-found)))
    (asserts! (is-eq tx-sender (get organizer meetup)) err-owner-only)
    (ok (map-set rsvp-list {meetup-id: meetup-id, attendee: attendee}
      (merge rsvp {speaker: true})))))
