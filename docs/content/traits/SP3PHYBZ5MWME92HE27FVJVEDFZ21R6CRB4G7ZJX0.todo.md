---
title: "Trait todo"
draft: true
---
```
;; Contract: Decentralized To-Do List
;; Description: Store and complete tasks on-chain.

(define-map tasks { user: principal, id: uint } { name: (string-ascii 40), done: bool })
(define-data-var task-counter uint u0)

(define-public (add-task (name (string-ascii 40)))
    (let
        (
            (new-id (+ (var-get task-counter) u1))
        )
        (var-set task-counter new-id)
        (map-set tasks { user: tx-sender, id: new-id } { name: name, done: false })
        (ok new-id)
    )
)

(define-public (complete-task (id uint))
    (let
        (
            (task (unwrap! (map-get? tasks { user: tx-sender, id: id }) (err u404)))
        )
        (map-set tasks { user: tx-sender, id: id } (merge task { done: true }))
        (ok "Task Completed")
    )
)
```
