;; Milestone Tracker

(define-map milestones { campaign-id: uint, milestone-id: uint } { description: (string-ascii 128), completed: bool })

(define-public (add-milestone (campaign-id uint) (milestone-id uint) (description (string-ascii 128)))
  (begin
    (map-set milestones { campaign-id: campaign-id, milestone-id: milestone-id } { description: description, completed: false })
    (ok true)
  )
)
