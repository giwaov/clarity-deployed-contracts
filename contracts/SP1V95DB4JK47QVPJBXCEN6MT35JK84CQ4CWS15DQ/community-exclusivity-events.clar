(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-not-member (err u102))
(define-constant err-invite-only (err u103))

(define-map exclusive-events
  uint
  {
    host: principal,
    event-title: (string-ascii 128),
    community: (string-ascii 128),
    exclusivity-tier: uint,
    date: uint,
    venue: (string-ascii 256),
    max-guests: uint,
    confirmed: uint,
    invite-only: bool
  })

(define-map community-members
  {community: (string-ascii 128), member: principal}
  {membership-tier: uint, joined-at: uint, invited-by: principal, verified: bool})

(define-map event-invitations
  {event-id: uint, invitee: principal}
  {invited-by: principal, accepted: bool, attended: bool})

(define-data-var next-event-id uint u0)

(define-read-only (get-event (event-id uint))
  (ok (map-get? exclusive-events event-id)))

(define-read-only (get-membership (community (string-ascii 128)) (member principal))
  (ok (map-get? community-members {community: community, member: member})))

(define-public (join-community (community (string-ascii 128)) (tier uint) (inviter principal))
  (begin
    (map-set community-members {community: community, member: tx-sender}
      {membership-tier: tier, joined-at: stacks-block-height, invited-by: inviter, verified: false})
    (ok true)))

(define-public (verify-member (community (string-ascii 128)) (member principal))
  (let ((membership (unwrap! (map-get? community-members {community: community, member: member}) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set community-members {community: community, member: member}
      (merge membership {verified: true})))))

(define-public (create-exclusive-event (title (string-ascii 128)) (community (string-ascii 128)) (tier uint) (date uint) (venue (string-ascii 256)) (max uint) (invite-only bool))
  (let ((event-id (var-get next-event-id)))
    (map-set exclusive-events event-id
      {host: tx-sender, event-title: title, community: community, exclusivity-tier: tier,
       date: date, venue: venue, max-guests: max, confirmed: u0, invite-only: invite-only})
    (var-set next-event-id (+ event-id u1))
    (ok event-id)))

(define-public (send-invitation (event-id uint) (invitee principal))
  (let ((event (unwrap! (map-get? exclusive-events event-id) err-not-found)))
    (asserts! (is-eq tx-sender (get host event)) err-owner-only)
    (ok (map-set event-invitations {event-id: event-id, invitee: invitee}
      {invited-by: tx-sender, accepted: false, attended: false}))))

(define-public (accept-invitation (event-id uint))
  (let ((event (unwrap! (map-get? exclusive-events event-id) err-not-found))
        (invitation (unwrap! (map-get? event-invitations {event-id: event-id, invitee: tx-sender}) err-invite-only))
        (membership (unwrap! (map-get? community-members {community: (get community event), member: tx-sender}) err-not-member)))
    (asserts! (get verified membership) err-not-member)
    (asserts! (>= (get membership-tier membership) (get exclusivity-tier event)) err-not-member)
    (map-set event-invitations {event-id: event-id, invitee: tx-sender}
      (merge invitation {accepted: true}))
    (ok (map-set exclusive-events event-id
      (merge event {confirmed: (+ (get confirmed event) u1)})))))

(define-public (mark-attended (event-id uint) (attendee principal))
  (let ((event (unwrap! (map-get? exclusive-events event-id) err-not-found))
        (invitation (unwrap! (map-get? event-invitations {event-id: event-id, invitee: attendee}) err-not-found)))
    (asserts! (is-eq tx-sender (get host event)) err-owner-only)
    (ok (map-set event-invitations {event-id: event-id, invitee: attendee}
      (merge invitation {attended: true})))))
