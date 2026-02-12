(define-data-var message-counter uint u0)

(define-map messages
  uint
  {
    author: principal,
    content: (string-utf8 256),
    timestamp: uint,
  }
)

(define-public (post-message (content (string-utf8 256)))
  (let ((msg-id (var-get message-counter)))
    (asserts! (> (len content) u0) (err u1))
    (map-set messages msg-id {
      author: tx-sender,
      content: content,
      timestamp: stacks-block-height,
    })
    (var-set message-counter (+ msg-id u1))
    (ok msg-id)
  )
)

(define-read-only (get-message (msg-id uint))
  (ok (map-get? messages msg-id))
)
