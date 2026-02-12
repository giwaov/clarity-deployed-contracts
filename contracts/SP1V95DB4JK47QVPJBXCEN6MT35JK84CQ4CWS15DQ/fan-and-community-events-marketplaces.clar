(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-not-member (err u102))
(define-constant err-capacity-reached (err u103))

(define-map fan-events
  uint
  {
    organizer: principal,
    community-name: (string-ascii 128),
    event-type: (string-ascii 64),
    date: uint,
    venue: (string-ascii 256),
    max-capacity: uint,
    tickets-sold: uint,
    general-price: uint,
    vip-price: uint
  })

(define-map community-memberships
  {community: (string-ascii 128), member: principal}
  {joined-at: uint, member-tier: (string-ascii 32), active: bool})

(define-map event-tickets
  {event-id: uint, ticket-id: uint}
  {owner: principal, ticket-type: (string-ascii 32), purchased-at: uint, used: bool})

(define-data-var next-event-id uint u0)

(define-read-only (get-event (event-id uint))
  (ok (map-get? fan-events event-id)))

(define-read-only (get-membership (community (string-ascii 128)) (member principal))
  (ok (map-get? community-memberships {community: community, member: member})))

(define-public (join-community (community (string-ascii 128)) (tier (string-ascii 32)))
  (begin
    (map-set community-memberships {community: community, member: tx-sender}
      {joined-at: stacks-block-height, member-tier: tier, active: true})
    (ok true)))

(define-public (create-fan-event (community (string-ascii 128)) (type (string-ascii 64)) (date uint) (venue (string-ascii 256)) (capacity uint) (general uint) (vip uint))
  (let ((event-id (var-get next-event-id)))
    (map-set fan-events event-id
      {organizer: tx-sender, community-name: community, event-type: type, date: date,
       venue: venue, max-capacity: capacity, tickets-sold: u0,
       general-price: general, vip-price: vip})
    (var-set next-event-id (+ event-id u1))
    (ok event-id)))

(define-public (buy-ticket (event-id uint) (ticket-type (string-ascii 32)))
  (let ((event (unwrap! (map-get? fan-events event-id) err-not-found))
        (ticket-id (get tickets-sold event))
        (price (if (is-eq ticket-type "VIP") (get vip-price event) (get general-price event)))
        (membership (map-get? community-memberships {community: (get community-name event), member: tx-sender})))
    (asserts! (is-some membership) err-not-member)
    (asserts! (< (get tickets-sold event) (get max-capacity event)) err-capacity-reached)
    (try! (stx-transfer? price tx-sender (get organizer event)))
    (map-set event-tickets {event-id: event-id, ticket-id: ticket-id}
      {owner: tx-sender, ticket-type: ticket-type, purchased-at: stacks-block-height, used: false})
    (ok (map-set fan-events event-id
      (merge event {tickets-sold: (+ (get tickets-sold event) u1)})))))

(define-public (use-ticket (event-id uint) (ticket-id uint))
  (let ((ticket (unwrap! (map-get? event-tickets {event-id: event-id, ticket-id: ticket-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get owner ticket)) err-owner-only)
    (ok (map-set event-tickets {event-id: event-id, ticket-id: ticket-id}
      (merge ticket {used: true})))))
