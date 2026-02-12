(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-capacity-full (err u102))
(define-constant err-not-creator (err u103))

(define-map creator-meetups
  uint
  {
    creator: principal,
    meetup-name: (string-ascii 128),
    content-niche: (string-ascii 64),
    format: (string-ascii 64),
    scheduled-block: uint,
    max-attendees: uint,
    registered: uint,
    ticket-price: uint,
    exclusive: bool
  })

(define-map creator-profiles
  principal
  {
    creator-name: (string-ascii 128),
    follower-count: uint,
    content-type: (string-ascii 64),
    verified: bool
  })

(define-map attendee-tickets
  {meetup-id: uint, attendee: principal}
  {purchased-at: uint, attended: bool, access-level: (string-ascii 32)})

(define-data-var next-meetup-id uint u0)

(define-read-only (get-meetup (meetup-id uint))
  (ok (map-get? creator-meetups meetup-id)))

(define-read-only (get-creator-profile (creator principal))
  (ok (map-get? creator-profiles creator)))

(define-public (register-creator (name (string-ascii 128)) (followers uint) (content-type (string-ascii 64)))
  (begin
    (map-set creator-profiles tx-sender
      {creator-name: name, follower-count: followers, content-type: content-type, verified: false})
    (ok true)))

(define-public (verify-creator (creator principal))
  (let ((profile (unwrap! (map-get? creator-profiles creator) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set creator-profiles creator (merge profile {verified: true})))))

(define-public (create-meetup (name (string-ascii 128)) (niche (string-ascii 64)) (format (string-ascii 64)) (scheduled uint) (max uint) (price uint) (exclusive bool))
  (let ((meetup-id (var-get next-meetup-id)))
    (asserts! (is-some (map-get? creator-profiles tx-sender)) err-not-creator)
    (map-set creator-meetups meetup-id
      {creator: tx-sender, meetup-name: name, content-niche: niche, format: format,
       scheduled-block: scheduled, max-attendees: max, registered: u0,
       ticket-price: price, exclusive: exclusive})
    (var-set next-meetup-id (+ meetup-id u1))
    (ok meetup-id)))

(define-public (purchase-ticket (meetup-id uint) (access-level (string-ascii 32)))
  (let ((meetup (unwrap! (map-get? creator-meetups meetup-id) err-not-found)))
    (asserts! (< (get registered meetup) (get max-attendees meetup)) err-capacity-full)
    (try! (stx-transfer? (get ticket-price meetup) tx-sender (get creator meetup)))
    (map-set attendee-tickets {meetup-id: meetup-id, attendee: tx-sender}
      {purchased-at: stacks-block-height, attended: false, access-level: access-level})
    (ok (map-set creator-meetups meetup-id
      (merge meetup {registered: (+ (get registered meetup) u1)})))))

(define-public (mark-attended (meetup-id uint) (attendee principal))
  (let ((meetup (unwrap! (map-get? creator-meetups meetup-id) err-not-found))
        (ticket (unwrap! (map-get? attendee-tickets {meetup-id: meetup-id, attendee: attendee}) err-not-found)))
    (asserts! (is-eq tx-sender (get creator meetup)) err-owner-only)
    (ok (map-set attendee-tickets {meetup-id: meetup-id, attendee: attendee}
      (merge ticket {attended: true})))))
