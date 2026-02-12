;; title: todo-list
;; version: 1.0.0
;; summary: Minimal on-chain task list with low storage footprint.
;; clarity: 4

;; constants
(define-constant contract-version "1.0.0")
(define-constant err-not-admin (err u900))
(define-constant err-admin-unset (err u901))
(define-constant err-admin-set (err u902))
(define-constant err-paused (err u903))
(define-constant err-admin-locked (err u904))
(define-constant err-not-owner (err u400))
(define-constant err-not-found (err u401))

;; data vars
(define-data-var next-task-id uint u0)
(define-data-var admin (optional principal) none)
(define-data-var paused bool false)
(define-data-var admin-locked bool false)

;; data maps
(define-map tasks
  {id: uint}
  {
    id: uint,
    owner: principal,
    completed: bool,
    created-at: uint
  }
)

;; private helpers
(define-private (assert-admin)
  (match (var-get admin)
    admin-principal (if (is-eq admin-principal tx-sender) (ok true) err-not-admin)
    err-admin-unset))

(define-private (assert-not-paused)
  (if (var-get paused) err-paused (ok true)))

;; admin
(define-public (init-admin)
  (begin
    (asserts! (is-none (var-get admin)) err-admin-set)
    (var-set admin (some tx-sender))
    (ok true)))

(define-public (set-admin (new-admin principal))
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (asserts! (not (var-get admin-locked)) err-admin-locked)
    (var-set admin (some new-admin))
    (ok true)))

(define-public (lock-admin)
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (var-set admin-locked true)
    (ok true)))

(define-public (pause)
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (var-set paused true)
    (ok true)))

(define-public (unpause)
  (begin
    (unwrap! (assert-admin) err-not-admin)
    (var-set paused false)
    (ok true)))

;; public functions
(define-public (create-task)
  (begin
    (unwrap! (assert-not-paused) err-paused)
    (let ((task-id (var-get next-task-id)))
      (begin
        (map-set tasks {id: task-id}
          {id: task-id, owner: tx-sender, completed: false, created-at: stacks-block-height})
        (var-set next-task-id (+ task-id u1))
        (ok task-id)))))

(define-public (set-completed (task-id uint) (completed bool))
  (let ((task (unwrap! (map-get? tasks {id: task-id}) err-not-found)))
    (begin
      (unwrap! (assert-not-paused) err-paused)
      (asserts! (is-eq (get owner task) tx-sender) err-not-owner)
      (map-set tasks {id: task-id} (merge task {completed: completed}))
      (ok true))))

(define-public (delete-task (task-id uint))
  (let ((task (unwrap! (map-get? tasks {id: task-id}) err-not-found)))
    (begin
      (unwrap! (assert-not-paused) err-paused)
      (asserts! (is-eq (get owner task) tx-sender) err-not-owner)
      (map-delete tasks {id: task-id})
      (ok true))))

;; read only functions
(define-read-only (get-task (task-id uint))
  (map-get? tasks {id: task-id}))

(define-read-only (get-next-task-id)
  (var-get next-task-id))

(define-read-only (get-admin)
  (var-get admin))

(define-read-only (is-paused)
  (var-get paused))

(define-read-only (is-admin-locked)
  (var-get admin-locked))

(define-read-only (get-version)
  contract-version)
