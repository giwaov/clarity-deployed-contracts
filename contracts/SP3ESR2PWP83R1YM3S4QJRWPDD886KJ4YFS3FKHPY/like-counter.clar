;; Like Counter

(define-map likes
  { post: uint, user: principal }
  { liked: bool }
)

(define-map like-totals
  uint
  { count: uint }
)

(define-public (like-post (post uint))
  (begin
    (asserts! (is-none (map-get? likes { post: post, user: tx-sender })) (err u409))
    (map-set likes { post: post, user: tx-sender } { liked: true })
    (let ((current (default-to { count: u0 } (map-get? like-totals post))))
      (map-set like-totals post { count: (+ (get count current) u1) })
    )
    (ok true)
  )
)

(define-public (unlike-post (post uint))
  (begin
    (asserts! (is-some (map-get? likes { post: post, user: tx-sender })) (err u404))
    (map-delete likes { post: post, user: tx-sender })
    (let ((current (default-to { count: u1 } (map-get? like-totals post))))
      (map-set like-totals post { count: (- (get count current) u1) })
    )
    (ok true)
  )
)

(define-read-only (has-liked (post uint) (user principal))
  (is-some (map-get? likes { post: post, user: user }))
)

(define-read-only (get-like-count (post uint))
  (default-to { count: u0 } (map-get? like-totals post))
)
