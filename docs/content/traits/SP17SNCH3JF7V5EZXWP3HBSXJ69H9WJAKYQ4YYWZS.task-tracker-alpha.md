---
title: "Trait task-tracker-alpha"
draft: true
---
```
;; Task tracking contract
(define-map tasks {id: uint} {owner: principal, title: (string-ascii 128), completed: bool})
(define-data-var task-counter uint u0)
(define-map user-tasks {user: principal, task-id: uint} bool)

(define-read-only (get-task (id uint))
  (map-get? tasks {id: id})
)

(define-public (create-task (title (string-ascii 128)))
  (let ((id (var-get task-counter)))
    (begin
      (map-set tasks {id: id} {owner: tx-sender, title: title, completed: false})
      (map-set user-tasks {user: tx-sender, task-id: id} true)
      (ok (var-set task-counter (+ id u1)))
    )
  )
)

(define-public (complete-task (id uint))
  (let ((task (unwrap! (map-get? tasks {id: id}) (err u1))))
    (begin
      (asserts! (is-eq tx-sender (get owner task)) (err u2))
      (ok (map-set tasks {id: id} (merge task {completed: true})))
    )
  )
)

```
