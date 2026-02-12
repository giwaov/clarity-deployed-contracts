;; Event logging contract
(define-map events {id: uint} {timestamp: uint, event-type: (string-ascii 64), data: (string-utf8 256)})
(define-data-var event-counter uint u0)

(define-read-only (get-event (id uint))
  (map-get? events {id: id})
)

(define-read-only (get-total-events)
  (var-get event-counter)
)

(define-public (log-event (event-type (string-ascii 64)) (data (string-utf8 256)))
  (let ((id (var-get event-counter)))
    (begin
      (map-set events {id: id} {
        timestamp: burn-block-height,
        event-type: event-type,
        data: data
      })
      (ok (var-set event-counter (+ id u1)))
    )
  )
)
