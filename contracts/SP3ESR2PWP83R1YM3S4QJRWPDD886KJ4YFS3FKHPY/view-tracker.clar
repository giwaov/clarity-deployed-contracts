;; View Tracker

(define-map views
  uint
  { count: uint }
)

(define-map viewed
  { content: uint, user: principal }
  { seen: bool }
)

(define-public (record-view (content uint))
  (begin
    (if (is-none (map-get? viewed { content: content, user: tx-sender }))
      (begin
        (map-set viewed { content: content, user: tx-sender } { seen: true })
        (let ((current (default-to { count: u0 } (map-get? views content))))
          (map-set views content { count: (+ (get count current) u1) })
        )
      )
      true
    )
    (ok true)
  )
)

(define-read-only (get-view-count (content uint))
  (default-to { count: u0 } (map-get? views content))
)

(define-read-only (has-viewed (content uint) (user principal))
  (is-some (map-get? viewed { content: content, user: user }))
)
