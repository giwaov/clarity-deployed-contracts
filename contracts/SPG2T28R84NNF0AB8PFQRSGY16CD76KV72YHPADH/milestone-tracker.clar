;; Milestone Tracker
(define-map milestones {project-id: uint, milestone-id: uint} {owner: principal, title: (string-ascii 100), target-date: uint, completed: bool})
(define-public (set-milestone (project-id uint) (milestone-id uint) (title (string-ascii 100)) (target-date uint) (completed bool))
  (begin (map-set milestones {project-id: project-id, milestone-id: milestone-id} {owner: tx-sender, title: title, target-date: target-date, completed: completed}) (ok true)))
(define-read-only (get-milestone (project-id uint) (milestone-id uint))
  (map-get? milestones {project-id: project-id, milestone-id: milestone-id}))
