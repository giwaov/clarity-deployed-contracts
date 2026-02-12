---
title: "Trait task-tracker"
draft: true
---
```
;; Task Tracker
(define-map tasks {task-id: uint, owner: principal} {title: (string-ascii 100), status: (string-ascii 20), priority: uint, due-date: uint})
(define-public (create-task (task-id uint) (title (string-ascii 100)) (status (string-ascii 20)) (priority uint) (due-date uint))
  (begin (map-set tasks {task-id: task-id, owner: tx-sender} {title: title, status: status, priority: priority, due-date: due-date}) (ok true)))
(define-read-only (get-task (task-id uint) (owner principal))
  (map-get? tasks {task-id: task-id, owner: owner}))

```
