(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ROBOT-NOT-FOUND (err u101))
(define-constant ERR-TASK-NOT-FOUND (err u102))

(define-map robot-registry
  { robot-id: (string-ascii 30) }
  {
    model: (string-ascii 50),
    location: (string-ascii 100),
    last-maintenance: uint,
    next-scheduled: uint,
    operational-hours: uint,
    owner: principal
  }
)

(define-map maintenance-tasks
  { robot-id: (string-ascii 30), task-id: uint }
  {
    task-type: (string-ascii 50),
    description: (string-ascii 200),
    scheduled-at: uint,
    completed-at: uint,
    technician: principal,
    status: (string-ascii 20)
  }
)

(define-data-var task-nonce uint u0)

(define-public (register-robot
  (robot-id (string-ascii 30))
  (model (string-ascii 50))
  (location (string-ascii 100))
)
  (ok (map-set robot-registry
    { robot-id: robot-id }
    {
      model: model,
      location: location,
      last-maintenance: u0,
      next-scheduled: u0,
      operational-hours: u0,
      owner: tx-sender
    }
  ))
)

(define-public (schedule-maintenance
  (robot-id (string-ascii 30))
  (task-id uint)
  (task-type (string-ascii 50))
  (description (string-ascii 200))
  (scheduled-at uint)
  (technician principal)
)
  (let ((robot (unwrap! (map-get? robot-registry { robot-id: robot-id }) ERR-ROBOT-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner robot)) ERR-NOT-AUTHORIZED)
    (ok (map-set maintenance-tasks
      { robot-id: robot-id, task-id: task-id }
      {
        task-type: task-type,
        description: description,
        scheduled-at: scheduled-at,
        completed-at: u0,
        technician: technician,
        status: "scheduled"
      }
    ))
  )
)

(define-public (complete-maintenance (robot-id (string-ascii 30)) (task-id uint))
  (let (
    (robot (unwrap! (map-get? robot-registry { robot-id: robot-id }) ERR-ROBOT-NOT-FOUND))
    (task (unwrap! (map-get? maintenance-tasks { robot-id: robot-id, task-id: task-id }) ERR-TASK-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get technician task)) ERR-NOT-AUTHORIZED)
    (map-set maintenance-tasks
      { robot-id: robot-id, task-id: task-id }
      (merge task { status: "completed", completed-at: stacks-block-height })
    )
    (ok (map-set robot-registry
      { robot-id: robot-id }
      (merge robot { last-maintenance: stacks-block-height })
    ))
  )
)

(define-public (update-operational-hours (robot-id (string-ascii 30)) (hours uint))
  (let ((robot (unwrap! (map-get? robot-registry { robot-id: robot-id }) ERR-ROBOT-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner robot)) ERR-NOT-AUTHORIZED)
    (ok (map-set robot-registry
      { robot-id: robot-id }
      (merge robot { operational-hours: hours })
    ))
  )
)

(define-read-only (get-robot-info (robot-id (string-ascii 30)))
  (map-get? robot-registry { robot-id: robot-id })
)

(define-read-only (get-task-info (robot-id (string-ascii 30)) (task-id uint))
  (map-get? maintenance-tasks { robot-id: robot-id, task-id: task-id })
)

(define-public (update-next-scheduled (robot-id (string-ascii 30)) (next-date uint))
  (let ((robot (unwrap! (map-get? robot-registry { robot-id: robot-id }) ERR-ROBOT-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get owner robot)) ERR-NOT-AUTHORIZED)
    (ok (map-set robot-registry
      { robot-id: robot-id }
      (merge robot { next-scheduled: next-date })
    ))
  )
)
