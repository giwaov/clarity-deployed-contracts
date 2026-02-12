;; Calendars
(define-map calendars {user: principal, date-id: uint} {busy: bool, notes: (string-ascii 100)})
(define-public (update-calendar (date-id uint) (busy bool) (notes (string-ascii 100)))
  (begin (map-set calendars {user: tx-sender, date-id: date-id} {busy: busy, notes: notes}) (ok true)))
(define-read-only (get-calendar (user principal) (date-id uint))
  (map-get? calendars {user: user, date-id: date-id}))
