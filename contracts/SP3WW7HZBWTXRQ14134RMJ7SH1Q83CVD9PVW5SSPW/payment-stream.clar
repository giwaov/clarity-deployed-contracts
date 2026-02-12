;; Payment Stream Contract

(define-data-var next-stream-id uint u1)

(define-map streams
  uint
  {
    sender: principal,
    recipient: principal,
    rate: uint,
    start-block: uint,
    active: bool
  }
)

(define-read-only (get-stream (stream-id uint))
  (map-get? streams stream-id)
)

(define-public (start-stream (recipient principal) (rate uint))
  (let ((stream-id (var-get next-stream-id)))
    (map-set streams stream-id {
      sender: tx-sender,
      recipient: recipient,
      rate: rate,
      start-block: block-height,
      active: true
    })
    (var-set next-stream-id (+ stream-id u1))
    (ok stream-id)
  )
)

(define-public (stop-stream (stream-id uint))
  (let ((stream (unwrap! (map-get? streams stream-id) (err u100))))
    (map-set streams stream-id (merge stream { active: false }))
    (ok true)
  )
)
