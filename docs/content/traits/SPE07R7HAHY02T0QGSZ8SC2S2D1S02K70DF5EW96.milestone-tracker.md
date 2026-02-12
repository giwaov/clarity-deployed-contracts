---
title: "Trait milestone-tracker"
draft: true
---
```
;; Milestone Tracker
(define-map milestones {project-id: uint, milestone-id: uint} {description: (string-ascii 100), achieved: bool})
(define-public (set-milestone (project-id uint) (milestone-id uint) (description (string-ascii 100)))
  (begin (map-set milestones {project-id: project-id, milestone-id: milestone-id} {description: description, achieved: false}) (ok true)))
(define-read-only (get-milestone (project-id uint) (milestone-id uint))
  (map-get? milestones {project-id: project-id, milestone-id: milestone-id}))

```
