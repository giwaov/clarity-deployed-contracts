;; Pause Control - Pause/unpause subscriptions

(define-map paused-subs
  { user: principal, creator: principal }
  {
    paused-at: uint,
    resume-at: uint
  }
)

(define-public (pause-sub (creator principal) (duration uint))
  (begin
    (map-set paused-subs { user: tx-sender, creator: creator } {
      paused-at: stacks-block-height,
      resume-at: (+ stacks-block-height duration)
    })
    (ok true)
  )
)

(define-public (resume-sub (creator principal))
  (begin
    (map-delete paused-subs { user: tx-sender, creator: creator })
    (ok true)
  )
)

(define-read-only (is-paused (user principal) (creator principal))
  (is-some (map-get? paused-subs { user: user, creator: creator }))
)
