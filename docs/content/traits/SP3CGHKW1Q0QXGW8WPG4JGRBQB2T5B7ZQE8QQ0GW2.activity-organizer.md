---
title: "Trait activity-organizer"
draft: true
---
```
;; Task Manager - Manage tasks
(define-map tasks uint {assignee: principal, description: (string-ascii 200), completed: bool})
(define-data-var task-id uint u0)

(define-public (create-task (assignee principal) (description (string-ascii 200)))
  (let ((id (var-get task-id)))
    (map-set tasks id {assignee: assignee, description: description, completed: false})
    (var-set task-id (+ id u1))
    (ok id)))

(define-read-only (get-task (id uint))
  (map-get? tasks id))

```
