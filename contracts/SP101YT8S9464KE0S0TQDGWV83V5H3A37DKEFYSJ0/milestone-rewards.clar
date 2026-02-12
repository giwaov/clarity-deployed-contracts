;; Milestone Rewards - Track and reward milestones

(define-map milestones
  { user: principal, milestone-type: (string-ascii 30) }
  {
    achieved: bool,
    achieved-at: (optional uint)
  }
)

(define-public (mark-milestone (milestone-type (string-ascii 30)))
  (begin
    (map-set milestones { user: tx-sender, milestone-type: milestone-type } {
      achieved: true,
      achieved-at: (some stacks-block-height)
    })
    (ok true)
  )
)

(define-read-only (has-milestone (user principal) (milestone-type (string-ascii 30)))
  (default-to false (get achieved (map-get? milestones { user: user, milestone-type: milestone-type })))
)
