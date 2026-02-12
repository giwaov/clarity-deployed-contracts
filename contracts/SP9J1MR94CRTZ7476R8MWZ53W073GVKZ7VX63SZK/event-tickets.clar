;; Event Tickets
(define-map tickets {ticket-id: uint} {event-name: (string-ascii 100), holder: principal, seat: (string-ascii 20), price: uint, used: bool})
(define-public (issue-ticket (ticket-id uint) (event-name (string-ascii 100)) (holder principal) (seat (string-ascii 20)) (price uint) (used bool))
  (begin (map-set tickets {ticket-id: ticket-id} {event-name: event-name, holder: holder, seat: seat, price: price, used: used}) (ok true)))
(define-read-only (get-ticket (ticket-id uint))
  (map-get? tickets {ticket-id: ticket-id}))
