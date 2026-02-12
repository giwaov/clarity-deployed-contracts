---
title: "Trait stackable"
draft: true
---
```

;; title: stackable
;; version: 1
;; summary: A decentralized task management smart contract.
;; description: Allows users to create, complete, and delete tasks on the Stacks blockchain.

;; traits
;;

;; constants
(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_TASK_NOT_FOUND (err u101))
(define-constant ERR_INVALID_TASK_DESC (err u102))
(define-constant ERR_UNDERFLOW (err u103))

;; data vars
(define-data-var counter uint u0)
(define-data-var next-task-id uint u0)

;; data maps
(define-map tasks
  uint
  {
    text: (string-utf8 256),
    completed: bool,
    created-at: uint,
    owner: principal
  }
)

(define-map user-task-count principal uint)

;; public functions

;; --- Counter Functions ---

(define-public (increment)
  (let
    ((new-value (+ (var-get counter) u1)))
    (begin
      (var-set counter new-value)
      (print {
        event: "counter-incremented",
        caller: tx-sender,
        new-value: new-value,
        block-height: block-height
      })
      (ok new-value)
    )
  )
)

(define-public (decrement)
  (let 
    ((current-value (var-get counter)))
    (begin
      ;; Prevent underflow
      (asserts! (> current-value u0) ERR_UNDERFLOW)
      (let
        ((new-value (- current-value u1)))
        (begin
          (var-set counter new-value)
          (print {
            event: "counter-decremented",
            caller: tx-sender,
            new-value: new-value,
            block-height: block-height
          })
          (ok new-value)
        )
      )
    )
  )
)

;; --- Task Functions ---

(define-public (add-task (task-text (string-utf8 256)))
  (let
    (
      (task-id (var-get next-task-id))
      (current-count (default-to u0 (map-get? user-task-count tx-sender)))
    )
    (begin
      (asserts! (> (len task-text) u0) ERR_INVALID_TASK_DESC)
      
      (map-set tasks task-id
        {
          text: task-text,
          completed: false,
          created-at: block-height,
          owner: tx-sender
        }
      )
      
      (map-set user-task-count tx-sender (+ current-count u1))
      (var-set next-task-id (+ task-id u1))
      
      (print {
        event: "task-created",
        task-id: task-id,
        owner: tx-sender,
        text: task-text,
        block-height: block-height
      })
      
      (ok task-id)
    )
  )
)

(define-public (complete-task (task-id uint))
  (let
    (
      (task (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND))
    )
    (begin
      (asserts! (is-eq (get owner task) tx-sender) ERR_NOT_AUTHORIZED)
      
      (map-set tasks task-id (merge task { completed: true }))
      
      (print {
        event: "task-completed",
        task-id: task-id,
        owner: tx-sender,
        block-height: block-height
      })
      
      (ok true)
    )
  )
)

(define-public (delete-task (task-id uint))
  (let
    (
      (task (unwrap! (map-get? tasks task-id) ERR_TASK_NOT_FOUND))
      (current-count (default-to u0 (map-get? user-task-count tx-sender)))
    )
    (begin
      (asserts! (is-eq (get owner task) tx-sender) ERR_NOT_AUTHORIZED)
      
      (map-delete tasks task-id)
      
      ;; Safety check although logically shouldn't underflow if map logic works
      (if (> current-count u0)
          (map-set user-task-count tx-sender (- current-count u1))
          (map-set user-task-count tx-sender u0)
      )
      
      (print {
        event: "task-deleted",
        task-id: task-id,
        owner: tx-sender,
        block-height: block-height
      })
      
      (ok true)
    )
  )
)

;; read only functions

(define-read-only (get-counter)
  (ok (var-get counter))
)

(define-read-only (get-task (task-id uint))
  (match (map-get? tasks task-id)
    task (ok task)
    ERR_TASK_NOT_FOUND
  )
)

(define-read-only (get-task-count (user principal))
  (ok (default-to u0 (map-get? user-task-count user)))
)

```
