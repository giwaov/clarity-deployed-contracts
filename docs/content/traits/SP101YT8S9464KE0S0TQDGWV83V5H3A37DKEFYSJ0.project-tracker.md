---
title: "Trait project-tracker"
draft: true
---
```
;; Project Tracker - Track projects
(define-map projects uint {owner: principal, title: (string-ascii 100), status: (string-ascii 20)})
(define-data-var project-id uint u0)

(define-public (create-project (title (string-ascii 100)))
  (let ((id (var-get project-id)))
    (map-set projects id {owner: tx-sender, title: title, status: "active"})
    (var-set project-id (+ id u1))
    (ok id)))

(define-read-only (get-project (id uint))
  (map-get? projects id))

```
