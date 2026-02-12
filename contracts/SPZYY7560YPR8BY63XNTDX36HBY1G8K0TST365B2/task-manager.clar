;; task-manager.clar
;; Personal task management system

;; Constants
(define-constant ERR-TASK-NOT-FOUND (err u100))
(define-constant ERR-NOT-CREATOR (err u101))
(define-constant ERR-TASK-ALREADY-COMPLETED (err u102))
(define-constant ERR-INVALID-DEADLINE (err u104))
(define-constant ERR-EMPTY-TITLE (err u105))

;; Status
(define-constant STATUS-PENDING u0)
(define-constant STATUS-IN-PROGRESS u1)
(define-constant STATUS-COMPLETED u2)

;; Data Variables
(define-data-var task-counter uint u0)

;; Maps
(define-map tasks uint 
  {
    creator: principal,
    title: (string-ascii 64),
    description: (string-ascii 256),
    priority: uint,
    status: uint,
    category: uint,
    created-at: uint,
    deadline: uint,
    completed-at: uint
  }
)

;; Public Functions
(define-public (create-task (title (string-ascii 64)) (description (string-ascii 256)) (priority uint) (category uint) (deadline uint))
  (let ((task-id (+ (var-get task-counter) u1)))
    (begin
      (asserts! (> (len title) u0) ERR-EMPTY-TITLE)
      (asserts! (> (len description) u0) (err u108))
      (asserts! (<= priority u3) (err u106))
      (asserts! (<= category u5) (err u107))
      (asserts! (or (is-eq deadline u0) (> deadline stacks-block-time)) ERR-INVALID-DEADLINE)
      
      (map-set tasks task-id {
        creator: tx-sender,
        title: title,
        description: description,
        priority: priority,
        status: STATUS-PENDING,
        category: category,
        created-at: stacks-block-time,
        deadline: deadline,
        completed-at: u0
      })
      
      (var-set task-counter task-id)
      (print { event: "task-created", id: task-id, creator: tx-sender })
      (ok task-id)
    )
  )
)

(define-public (update-task (task-id uint) (title (string-ascii 64)) (description (string-ascii 256)) (priority uint))
  (let ((task (unwrap! (map-get? tasks task-id) ERR-TASK-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get creator task) tx-sender) ERR-NOT-CREATOR)
      (asserts! (is-eq (get status task) STATUS-PENDING) ERR-TASK-ALREADY-COMPLETED)
      (asserts! (> (len title) u0) ERR-EMPTY-TITLE)
      
      (map-set tasks task-id (merge task {
        title: title,
        description: description,
        priority: priority
      }))
      (ok true)
    )
  )
)

(define-public (start-task (task-id uint))
  (let ((task (unwrap! (map-get? tasks task-id) ERR-TASK-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get creator task) tx-sender) ERR-NOT-CREATOR)
      (asserts! (is-eq (get status task) STATUS-PENDING) ERR-TASK-ALREADY-COMPLETED)
      
      (map-set tasks task-id (merge task { status: STATUS-IN-PROGRESS }))
      (ok true)
    )
  )
)

(define-public (complete-task (task-id uint))
  (let ((task (unwrap! (map-get? tasks task-id) ERR-TASK-NOT-FOUND)))
    (begin
      (asserts! (is-eq (get creator task) tx-sender) ERR-NOT-CREATOR)
      (asserts! (not (is-eq (get status task) STATUS-COMPLETED)) ERR-TASK-ALREADY-COMPLETED)
      
      (map-set tasks task-id (merge task { 
        status: STATUS-COMPLETED,
        completed-at: stacks-block-time
      }))
      (ok true)
    )
  )
)

;; Read-only
(define-read-only (get-task (task-id uint))
  (map-get? tasks task-id)
)
