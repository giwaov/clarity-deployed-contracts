;; event-tickets.clar
;; Stub for ticketing

(define-map tickets { event: uint, seat: uint } principal)

(define-public (buy-ticket (event uint) (seat uint))
    (begin
        (asserts! (is-none (map-get? tickets { event: event, seat: seat })) (err u100))
        (map-set tickets { event: event, seat: seat } tx-sender)
        (ok true)
    )
)
