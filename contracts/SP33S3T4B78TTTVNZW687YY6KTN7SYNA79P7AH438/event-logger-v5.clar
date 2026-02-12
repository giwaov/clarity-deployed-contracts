(define-data-var event-counter uint u0)

(define-map events
  uint
  {
    actor: principal,
    action: (string-ascii 50),
    timestamp: uint,
  }
)

(define-public (log-event (action (string-ascii 50)))
  (let ((event-id (var-get event-counter)))
    (asserts! (> (len action) u0) (err u1))
    (map-set events event-id {
      actor: tx-sender,
      action: action,
      timestamp: stacks-block-height,
    })
    (var-set event-counter (+ event-id u1))
    (ok event-id)
  )
)

(define-read-only (get-event (event-id uint))
  (ok (map-get? events event-id))
)
