---
title: "Trait task-tracker"
draft: true
---
```
;; Task Tracker
(define-map tasks uint {owner: principal, title: (string-ascii 100), completed: bool})
(define-data-var task-counter uint u0)
(define-public (create-task (title (string-ascii 100)))
  (let ((id (var-get task-counter)))
    (map-set tasks id {owner: tx-sender, title: title, completed: false})
    (var-set task-counter (+ id u1))
    (ok id)))
(define-read-only (get-task (id uint))
  (map-get? tasks id))

```
