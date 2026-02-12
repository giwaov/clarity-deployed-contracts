;; Comment System - Post and manage comments

(define-map comments
  uint
  {
    author: principal,
    text: (string-utf8 500),
    created-at: uint,
    likes: uint
  }
)

(define-data-var comment-counter uint u0)

(define-public (post-comment (text (string-utf8 500)))
  (let ((id (var-get comment-counter)))
    (map-set comments id {
      author: tx-sender,
      text: text,
      created-at: stacks-block-height,
      likes: u0
    })
    (var-set comment-counter (+ id u1))
    (ok id)
  )
)

(define-public (like-comment (id uint))
  (let ((comment (unwrap! (map-get? comments id) (err u404))))
    (map-set comments id (merge comment { likes: (+ (get likes comment) u1) }))
    (ok true)
  )
)

(define-read-only (get-comment (id uint))
  (map-get? comments id)
)
