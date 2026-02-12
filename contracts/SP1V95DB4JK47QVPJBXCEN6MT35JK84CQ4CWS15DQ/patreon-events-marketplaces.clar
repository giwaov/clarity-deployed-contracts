(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-not-patron (err u102))
(define-constant err-tier-required (err u103))

(define-map patron-events
  uint
  {
    creator: principal,
    event-name: (string-ascii 128),
    event-format: (string-ascii 64),
    scheduled-block: uint,
    min-tier-required: uint,
    max-attendees: uint,
    registered: uint,
    exclusive-content: bool
  })

(define-map patron-tiers
  {creator: principal, patron: principal}
  {tier-level: uint, monthly-pledge: uint, joined-at: uint, active: bool})

(define-map event-registrations
  {event-id: uint, patron: principal}
  {registered-at: uint, attended: bool})

(define-data-var next-event-id uint u0)

(define-read-only (get-event (event-id uint))
  (ok (map-get? patron-events event-id)))

(define-read-only (get-patron-tier (creator principal) (patron principal))
  (ok (map-get? patron-tiers {creator: creator, patron: patron})))

(define-public (become-patron (creator principal) (tier uint) (pledge uint))
  (begin
    (try! (stx-transfer? pledge tx-sender creator))
    (map-set patron-tiers {creator: creator, patron: tx-sender}
      {tier-level: tier, monthly-pledge: pledge, joined-at: stacks-block-height, active: true})
    (ok true)))

(define-public (create-patron-event (name (string-ascii 128)) (format (string-ascii 64)) (scheduled uint) (min-tier uint) (max uint) (exclusive bool))
  (let ((event-id (var-get next-event-id)))
    (map-set patron-events event-id
      {creator: tx-sender, event-name: name, event-format: format,
       scheduled-block: scheduled, min-tier-required: min-tier, max-attendees: max,
       registered: u0, exclusive-content: exclusive})
    (var-set next-event-id (+ event-id u1))
    (ok event-id)))

(define-public (register-for-event (event-id uint))
  (let ((event (unwrap! (map-get? patron-events event-id) err-not-found))
        (patron-info (unwrap! (map-get? patron-tiers {creator: (get creator event), patron: tx-sender}) err-not-patron)))
    (asserts! (get active patron-info) err-not-patron)
    (asserts! (>= (get tier-level patron-info) (get min-tier-required event)) err-tier-required)
    (asserts! (< (get registered event) (get max-attendees event)) err-not-found)
    (map-set event-registrations {event-id: event-id, patron: tx-sender}
      {registered-at: stacks-block-height, attended: false})
    (ok (map-set patron-events event-id
      (merge event {registered: (+ (get registered event) u1)})))))

(define-public (mark-attendance (event-id uint) (patron principal))
  (let ((event (unwrap! (map-get? patron-events event-id) err-not-found))
        (registration (unwrap! (map-get? event-registrations {event-id: event-id, patron: patron}) err-not-found)))
    (asserts! (is-eq tx-sender (get creator event)) err-owner-only)
    (ok (map-set event-registrations {event-id: event-id, patron: patron}
      (merge registration {attended: true})))))

(define-public (cancel-patronage (creator principal))
  (let ((patron-info (unwrap! (map-get? patron-tiers {creator: creator, patron: tx-sender}) err-not-patron)))
    (ok (map-set patron-tiers {creator: creator, patron: tx-sender}
      (merge patron-info {active: false})))))
