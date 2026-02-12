---
title: "Trait task-tracker-a3"
draft: true
---
```
;; task-tracker.clar
;; Task management system

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-state (err u103))

;; Data Maps
(define-map tasks 
    { task-id: uint } 
    { 
        creator: principal,
        assignee: (optional principal),
        title: (string-ascii 64),
        description: (string-utf8 256),
        status: (string-ascii 20), ;; "open", "in-progress", "completed", "verified"
        reward: uint,
        created-at: uint,
        updated-at: uint
    }
)

(define-map user-tasks { user: principal } { created: uint, completed: uint, earned: uint })
(define-map project-stats { project-id: uint } { total-tasks: uint, completed-tasks: uint })

;; Variables
(define-data-var next-task-id uint u1)

;; Read-only functions

(define-read-only (get-task (task-id uint))
    (map-get? tasks { task-id: task-id }))

(define-read-only (get-user-stats (user principal))
    (default-to { created: u0, completed: u0, earned: u0 } (map-get? user-tasks { user: user })))

(define-read-only (get-next-task-id)
    (var-get next-task-id))

;; Public functions

(define-public (create-task (title (string-ascii 64)) (description (string-utf8 256)) (reward uint))
    (let ((id (var-get next-task-id)))
        (map-set tasks { task-id: id } 
                 { 
                     creator: tx-sender,
                     assignee: none,
                     title: title,
                     description: description,
                     status: "open",
                     reward: reward,
                     created-at: burn-block-height,
                     updated-at: burn-block-height
                 })
        (var-set next-task-id (+ id u1))
        (match (map-get? user-tasks { user: tx-sender })
            stats (map-set user-tasks { user: tx-sender } (merge stats { created: (+ (get created stats) u1) }))
            (map-set user-tasks { user: tx-sender } { created: u1, completed: u0, earned: u0 }))
        (ok id)))

(define-public (assign-task (task-id uint) (assignee principal))
    (match (map-get? tasks { task-id: task-id })
        task (begin
                (asserts! (is-eq (get creator task) tx-sender) err-unauthorized)
                (asserts! (is-eq (get status task) "open") err-invalid-state)
                (map-set tasks { task-id: task-id } 
                         (merge task { assignee: (some assignee), status: "in-progress", updated-at: burn-block-height }))
                (ok true))
        err-not-found))

(define-public (complete-task (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (begin
                (asserts! (is-eq (some tx-sender) (get assignee task)) err-unauthorized)
                (asserts! (is-eq (get status task) "in-progress") err-invalid-state)
                (map-set tasks { task-id: task-id } 
                         (merge task { status: "completed", updated-at: burn-block-height }))
                (ok true))
        err-not-found))

(define-public (verify-task (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (begin
                (asserts! (is-eq (get creator task) tx-sender) err-unauthorized)
                (asserts! (is-eq (get status task) "completed") err-invalid-state)
                (map-set tasks { task-id: task-id } 
                         (merge task { status: "verified", updated-at: burn-block-height }))
                (match (get assignee task)
                    assignee (match (map-get? user-tasks { user: assignee })
                                stats (map-set user-tasks { user: assignee } 
                                               (merge stats { completed: (+ (get completed stats) u1), earned: (+ (get earned stats) (get reward task)) }))
                                (map-set user-tasks { user: assignee } { created: u0, completed: u1, earned: (get reward task) }))
                    false)
                (ok true))
        err-not-found))

(define-public (cancel-task (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (begin
                (asserts! (is-eq (get creator task) tx-sender) err-unauthorized)
                (asserts! (or (is-eq (get status task) "open") (is-eq (get status task) "in-progress")) err-invalid-state)
                (map-delete tasks { task-id: task-id })
                (ok true))
        err-not-found))

(define-public (update-task-title (task-id uint) (new-title (string-ascii 64)))
    (match (map-get? tasks { task-id: task-id })
        task (begin
                (asserts! (is-eq (get creator task) tx-sender) err-unauthorized)
                (map-set tasks { task-id: task-id } (merge task { title: new-title, updated-at: burn-block-height }))
                (ok true))
        err-not-found))

(define-public (update-task-description (task-id uint) (new-desc (string-utf8 256)))
    (match (map-get? tasks { task-id: task-id })
        task (begin
                (asserts! (is-eq (get creator task) tx-sender) err-unauthorized)
                (map-set tasks { task-id: task-id } (merge task { description: new-desc, updated-at: burn-block-height }))
                (ok true))
        err-not-found))

(define-public (update-task-reward (task-id uint) (new-reward uint))
    (match (map-get? tasks { task-id: task-id })
        task (begin
                (asserts! (is-eq (get creator task) tx-sender) err-unauthorized)
                (map-set tasks { task-id: task-id } (merge task { reward: new-reward, updated-at: burn-block-height }))
                (ok true))
        err-not-found))

(define-public (unassign-task (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (begin
                (asserts! (is-eq (get creator task) tx-sender) err-unauthorized)
                (map-set tasks { task-id: task-id } (merge task { assignee: none, status: "open", updated-at: burn-block-height }))
                (ok true))
        err-not-found))

;; Helper functions for quota

(define-public (is-task-open (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (ok (is-eq (get status task) "open"))
        err-not-found))

(define-public (is-task-completed (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (ok (is-eq (get status task) "completed"))
        err-not-found))

(define-public (is-task-verified (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (ok (is-eq (get status task) "verified"))
        err-not-found))

(define-public (get-task-creator (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (ok (get creator task))
        err-not-found))

(define-public (get-task-assignee (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (ok (get assignee task))
        err-not-found))

(define-public (get-task-reward (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (ok (get reward task))
        err-not-found))

(define-public (admin-delete-task (task-id uint))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-delete tasks { task-id: task-id })
        (ok true)))

(define-public (admin-set-status (task-id uint) (new-status (string-ascii 20)))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (match (map-get? tasks { task-id: task-id })
            task (begin
                    (map-set tasks { task-id: task-id } (merge task { status: new-status }))
                    (ok true))
            err-not-found)))

(define-public (get-user-created-count (user principal))
    (ok (get created (get-user-stats user))))

(define-public (get-user-completed-count (user principal))
    (ok (get completed (get-user-stats user))))

(define-public (get-user-earned-total (user principal))
    (ok (get earned (get-user-stats user))))

(define-public (reset-user-stats (user principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-delete user-tasks { user: user })
        (ok true)))

(define-public (check-task-exists (task-id uint))
    (ok (is-some (map-get? tasks { task-id: task-id }))))

(define-public (get-tasks-in-range (start-id uint) (end-id uint))
    (ok (- end-id start-id))) ;; Placeholder

(define-public (get-task-age (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (ok (- burn-block-height (get created-at task)))
        err-not-found))

(define-public (is-task-overdue (task-id uint) (deadline uint))
    (match (map-get? tasks { task-id: task-id })
        task (ok (> burn-block-height deadline))
        err-not-found))

(define-public (get-task-efficiency (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (ok (/ (get reward task) (if (> (- (get updated-at task) (get created-at task)) u0) 
                                          (- (get updated-at task) (get created-at task)) 
                                          u1)))
        err-not-found))

(define-public (check-assignee-reliability (user principal))
    (let ((stats (get-user-stats user)))
        (ok (if (> (get created stats) u0) 
                (/ (* (get completed stats) u100) (get created stats)) 
                u0))))

(define-public (get-task-status-code (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (ok (if (is-eq (get status task) "open") u1
                 (if (is-eq (get status task) "in-progress") u2
                 (if (is-eq (get status task) "completed") u3
                 (if (is-eq (get status task) "verified") u4 u0)))))
        err-not-found))

(define-public (can-claim-task (task-id uint) (user principal))
    (match (map-get? tasks { task-id: task-id })
        task (ok (and (is-eq (get status task) "open") (is-none (get assignee task))))
        err-not-found))

(define-public (get-completion-time (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (ok (if (is-eq (get status task) "completed")
                     (- (get updated-at task) (get created-at task))
                     u0))
        err-not-found))

(define-public (is-high-value-task (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (ok (> (get reward task) u1000))
        err-not-found))

(define-public (get-task-priority (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (ok (if (> (get reward task) u5000) u3 
                 (if (> (get reward task) u1000) u2 u1)))
        err-not-found))

(define-public (get-active-task-count (user principal))
    (ok u0)) ;; Placeholder for more complex query

(define-public (get-total-rewards-paid)
    (ok u0)) ;; Placeholder

(define-public (is-task-creator (task-id uint) (user principal))
    (match (map-get? tasks { task-id: task-id })
        task (ok (is-eq (get creator task) user))
        err-not-found))

(define-public (is-task-assignee (task-id uint) (user principal))
    (match (map-get? tasks { task-id: task-id })
        task (ok (is-eq (some user) (get assignee task)))
        err-not-found))

(define-public (get-time-since-update (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (ok (- burn-block-height (get updated-at task)))
        err-not-found))

(define-public (check-task-stale (task-id uint) (threshold uint))
    (match (map-get? tasks { task-id: task-id })
        task (ok (> (- burn-block-height (get updated-at task)) threshold))
        err-not-found))

(define-public (estimate-task-difficulty (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (ok (/ (get reward task) u100))
        err-not-found))

(define-public (get-task-lifecycle-duration (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (ok (- burn-block-height (get created-at task)))
        err-not-found))

(define-public (is-reward-claimable (task-id uint))
    (match (map-get? tasks { task-id: task-id })
        task (ok (is-eq (get status task) "verified"))
        err-not-found))

(define-public (get-min-reward-threshold)
    (ok u100))

(define-public (get-max-reward-cap)
    (ok u1000000))

(define-public (validate-task-title (title (string-ascii 64)))
    (ok (> (len title) u3)))

(define-public (validate-task-desc (desc (string-utf8 256)))
    (ok (> (len desc) u10)))

(define-public (calculate-platform-fee (reward uint))
    (ok (/ reward u20)))

(define-public (get-recommended-reward (difficulty uint))
    (ok (* difficulty u100)))

(define-public (is-system-healthy)
    (ok true))

```
