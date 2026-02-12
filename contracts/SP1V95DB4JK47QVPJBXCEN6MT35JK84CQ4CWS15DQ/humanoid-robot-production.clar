(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ROBOT-NOT-FOUND (err u101))
(define-constant ERR-BATCH-NOT-FOUND (err u102))

(define-map production-batches
  { batch-id: uint }
  {
    robot-model: (string-ascii 50),
    target-quantity: uint,
    produced-quantity: uint,
    started-at: uint,
    completed-at: uint,
    status: (string-ascii 20),
    manufacturer: principal
  }
)

(define-map robot-units
  { batch-id: uint, robot-id: uint }
  {
    serial-number: (string-ascii 30),
    actuator-count: uint,
    sensor-count: uint,
    ai-chip-model: (string-ascii 30),
    assembly-stage: (string-ascii 30),
    tested: bool,
    completed: bool
  }
)

(define-data-var batch-nonce uint u0)

(define-public (start-production
  (robot-model (string-ascii 50))
  (target-quantity uint)
)
  (let ((batch-id (var-get batch-nonce)))
    (map-set production-batches
      { batch-id: batch-id }
      {
        robot-model: robot-model,
        target-quantity: target-quantity,
        produced-quantity: u0,
        started-at: stacks-block-height,
        completed-at: u0,
        status: "in-progress",
        manufacturer: tx-sender
      }
    )
    (var-set batch-nonce (+ batch-id u1))
    (ok batch-id)
  )
)

(define-public (add-robot
  (batch-id uint)
  (robot-id uint)
  (serial-number (string-ascii 30))
  (actuator-count uint)
  (sensor-count uint)
  (ai-chip (string-ascii 30))
)
  (let ((batch (unwrap! (map-get? production-batches { batch-id: batch-id }) ERR-BATCH-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get manufacturer batch)) ERR-NOT-AUTHORIZED)
    (ok (map-set robot-units
      { batch-id: batch-id, robot-id: robot-id }
      {
        serial-number: serial-number,
        actuator-count: actuator-count,
        sensor-count: sensor-count,
        ai-chip-model: ai-chip,
        assembly-stage: "frame",
        tested: false,
        completed: false
      }
    ))
  )
)

(define-public (update-assembly-stage (batch-id uint) (robot-id uint) (new-stage (string-ascii 30)))
  (let (
    (batch (unwrap! (map-get? production-batches { batch-id: batch-id }) ERR-BATCH-NOT-FOUND))
    (robot (unwrap! (map-get? robot-units { batch-id: batch-id, robot-id: robot-id }) ERR-ROBOT-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get manufacturer batch)) ERR-NOT-AUTHORIZED)
    (ok (map-set robot-units
      { batch-id: batch-id, robot-id: robot-id }
      (merge robot { assembly-stage: new-stage })
    ))
  )
)

(define-public (complete-testing (batch-id uint) (robot-id uint))
  (let (
    (batch (unwrap! (map-get? production-batches { batch-id: batch-id }) ERR-BATCH-NOT-FOUND))
    (robot (unwrap! (map-get? robot-units { batch-id: batch-id, robot-id: robot-id }) ERR-ROBOT-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get manufacturer batch)) ERR-NOT-AUTHORIZED)
    (ok (map-set robot-units
      { batch-id: batch-id, robot-id: robot-id }
      (merge robot { tested: true, completed: true })
    ))
  )
)

(define-read-only (get-batch-info (batch-id uint))
  (map-get? production-batches { batch-id: batch-id })
)

(define-read-only (get-robot-info (batch-id uint) (robot-id uint))
  (map-get? robot-units { batch-id: batch-id, robot-id: robot-id })
)

(define-public (complete-batch (batch-id uint))
  (let ((batch (unwrap! (map-get? production-batches { batch-id: batch-id }) ERR-BATCH-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get manufacturer batch)) ERR-NOT-AUTHORIZED)
    (ok (map-set production-batches
      { batch-id: batch-id }
      (merge batch { status: "completed", completed-at: stacks-block-height })
    ))
  )
)
