(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-sold-out (err u102))
(define-constant err-event-ended (err u103))

(define-map events
  uint
  {
    organizer: principal,
    name: (string-ascii 128),
    category: (string-ascii 64),
    venue: (string-ascii 256),
    event-date: uint,
    total-tickets: uint,
    sold-tickets: uint,
    ticket-price: uint,
    active: bool
  })

(define-map tickets
  {event-id: uint, ticket-id: uint}
  {owner: principal, purchased-at: uint, used: bool})

(define-data-var next-event-id uint u0)

(define-read-only (get-event (event-id uint))
  (ok (map-get? events event-id)))

(define-read-only (get-ticket (event-id uint) (ticket-id uint))
  (ok (map-get? tickets {event-id: event-id, ticket-id: ticket-id})))

(define-public (create-event (name (string-ascii 128)) (category (string-ascii 64)) (venue (string-ascii 256)) (date uint) (total uint) (price uint))
  (let ((event-id (var-get next-event-id)))
    (map-set events event-id
      {organizer: tx-sender, name: name, category: category, venue: venue,
       event-date: date, total-tickets: total, sold-tickets: u0, ticket-price: price, active: true})
    (var-set next-event-id (+ event-id u1))
    (ok event-id)))

(define-public (purchase-ticket (event-id uint))
  (let ((event (unwrap! (map-get? events event-id) err-not-found))
        (ticket-id (get sold-tickets event)))
    (asserts! (get active event) err-event-ended)
    (asserts! (< (get sold-tickets event) (get total-tickets event)) err-sold-out)
    (try! (stx-transfer? (get ticket-price event) tx-sender (get organizer event)))
    (map-set tickets {event-id: event-id, ticket-id: ticket-id}
      {owner: tx-sender, purchased-at: stacks-block-height, used: false})
    (map-set events event-id (merge event {sold-tickets: (+ ticket-id u1)}))
    (ok ticket-id)))

(define-public (cancel-event (event-id uint))
  (let ((event (unwrap! (map-get? events event-id) err-not-found)))
    (asserts! (is-eq tx-sender (get organizer event)) err-owner-only)
    (ok (map-set events event-id (merge event {active: false})))))

(define-public (use-ticket (event-id uint) (ticket-id uint))
  (let ((ticket (unwrap! (map-get? tickets {event-id: event-id, ticket-id: ticket-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get owner ticket)) err-owner-only)
    (ok (map-set tickets {event-id: event-id, ticket-id: ticket-id} (merge ticket {used: true})))))
