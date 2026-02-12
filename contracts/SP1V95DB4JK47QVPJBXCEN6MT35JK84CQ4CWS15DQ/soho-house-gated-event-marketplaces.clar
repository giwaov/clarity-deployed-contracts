(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-not-member (err u102))
(define-constant err-membership-required (err u103))

(define-map gated-events
  uint
  {
    host: principal,
    event-title: (string-ascii 128),
    club-name: (string-ascii 128),
    membership-tier-required: uint,
    date: uint,
    venue: (string-ascii 256),
    max-capacity: uint,
    rsvps: uint,
    members-only: bool
  })

(define-map club-memberships
  {club: (string-ascii 128), member: principal}
  {membership-tier: uint, joined-at: uint, sponsor: principal, dues-paid: bool, active: bool})

(define-map event-rsvps
  {event-id: uint, member: principal}
  {rsvp-at: uint, plus-ones: uint, attended: bool})

(define-data-var next-event-id uint u0)

(define-read-only (get-event (event-id uint))
  (ok (map-get? gated-events event-id)))

(define-read-only (get-membership (club (string-ascii 128)) (member principal))
  (ok (map-get? club-memberships {club: club, member: member})))

(define-public (apply-membership (club (string-ascii 128)) (tier uint) (sponsor principal))
  (begin
    (map-set club-memberships {club: club, member: tx-sender}
      {membership-tier: tier, joined-at: stacks-block-height, sponsor: sponsor,
       dues-paid: false, active: false})
    (ok true)))

(define-public (approve-membership (club (string-ascii 128)) (member principal))
  (let ((membership (unwrap! (map-get? club-memberships {club: club, member: member}) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set club-memberships {club: club, member: member}
      (merge membership {active: true})))))

(define-public (pay-dues (club (string-ascii 128)) (amount uint))
  (let ((membership (unwrap! (map-get? club-memberships {club: club, member: tx-sender}) err-not-member)))
    (try! (stx-transfer? amount tx-sender contract-owner))
    (ok (map-set club-memberships {club: club, member: tx-sender}
      (merge membership {dues-paid: true})))))

(define-public (create-gated-event (title (string-ascii 128)) (club (string-ascii 128)) (tier-req uint) (date uint) (venue (string-ascii 256)) (capacity uint) (members-only bool))
  (let ((event-id (var-get next-event-id)))
    (map-set gated-events event-id
      {host: tx-sender, event-title: title, club-name: club, membership-tier-required: tier-req,
       date: date, venue: venue, max-capacity: capacity, rsvps: u0, members-only: members-only})
    (var-set next-event-id (+ event-id u1))
    (ok event-id)))

(define-public (rsvp-event (event-id uint) (plus-ones uint))
  (let ((event (unwrap! (map-get? gated-events event-id) err-not-found))
        (membership (unwrap! (map-get? club-memberships {club: (get club-name event), member: tx-sender}) err-not-member)))
    (asserts! (get active membership) err-not-member)
    (asserts! (get dues-paid membership) err-membership-required)
    (asserts! (>= (get membership-tier membership) (get membership-tier-required event)) err-membership-required)
    (map-set event-rsvps {event-id: event-id, member: tx-sender}
      {rsvp-at: stacks-block-height, plus-ones: plus-ones, attended: false})
    (ok (map-set gated-events event-id
      (merge event {rsvps: (+ (get rsvps event) u1)})))))

(define-public (check-in-member (event-id uint) (member principal))
  (let ((event (unwrap! (map-get? gated-events event-id) err-not-found))
        (rsvp (unwrap! (map-get? event-rsvps {event-id: event-id, member: member}) err-not-found)))
    (asserts! (is-eq tx-sender (get host event)) err-owner-only)
    (ok (map-set event-rsvps {event-id: event-id, member: member}
      (merge rsvp {attended: true})))))
