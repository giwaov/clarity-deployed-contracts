(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-sold-out (err u102))
(define-constant err-invalid-rating (err u103))

(define-map art-events
  uint
  {
    organizer: principal,
    event-name: (string-ascii 128),
    art-category: (string-ascii 64),
    venue: (string-ascii 256),
    performance-date: uint,
    total-seats: uint,
    seats-sold: uint,
    ticket-tiers: (list 5 uint),
    featured-artists: (list 10 principal)
  })

(define-map event-tickets
  {event-id: uint, ticket-id: uint}
  {purchaser: principal, tier: uint, seat-number: uint, price-paid: uint, used: bool})

(define-map artist-profiles
  principal
  {
    artist-name: (string-ascii 128),
    art-form: (string-ascii 64),
    performances: uint,
    rating: uint
  })

(define-data-var next-event-id uint u0)

(define-read-only (get-event (event-id uint))
  (ok (map-get? art-events event-id)))

(define-read-only (get-ticket (event-id uint) (ticket-id uint))
  (ok (map-get? event-tickets {event-id: event-id, ticket-id: ticket-id})))

(define-public (register-artist (name (string-ascii 128)) (art-form (string-ascii 64)))
  (begin
    (map-set artist-profiles tx-sender
      {artist-name: name, art-form: art-form, performances: u0, rating: u0})
    (ok true)))

(define-public (create-art-event (name (string-ascii 128)) (category (string-ascii 64)) (venue (string-ascii 256)) (date uint) (seats uint) (tiers (list 5 uint)) (artists (list 10 principal)))
  (let ((event-id (var-get next-event-id)))
    (map-set art-events event-id
      {organizer: tx-sender, event-name: name, art-category: category, venue: venue,
       performance-date: date, total-seats: seats, seats-sold: u0,
       ticket-tiers: tiers, featured-artists: artists})
    (var-set next-event-id (+ event-id u1))
    (ok event-id)))

(define-public (purchase-ticket (event-id uint) (tier uint) (seat uint))
  (let ((event (unwrap! (map-get? art-events event-id) err-not-found))
        (ticket-id (get seats-sold event))
        (price (unwrap! (element-at (get ticket-tiers event) tier) err-not-found)))
    (asserts! (< (get seats-sold event) (get total-seats event)) err-sold-out)
    (try! (stx-transfer? price tx-sender (get organizer event)))
    (map-set event-tickets {event-id: event-id, ticket-id: ticket-id}
      {purchaser: tx-sender, tier: tier, seat-number: seat, price-paid: price, used: false})
    (ok (map-set art-events event-id
      (merge event {seats-sold: (+ (get seats-sold event) u1)})))))

(define-public (redeem-ticket (event-id uint) (ticket-id uint))
  (let ((ticket (unwrap! (map-get? event-tickets {event-id: event-id, ticket-id: ticket-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get purchaser ticket)) err-owner-only)
    (ok (map-set event-tickets {event-id: event-id, ticket-id: ticket-id}
      (merge ticket {used: true})))))

(define-public (rate-performance (artist principal) (rating uint))
  (let ((profile (unwrap! (map-get? artist-profiles artist) err-not-found)))
    (asserts! (<= rating u5) err-invalid-rating)
    (ok (map-set artist-profiles artist
      (merge profile {performances: (+ (get performances profile) u1),
                      rating: (/ (+ (get rating profile) rating) u2)})))))
