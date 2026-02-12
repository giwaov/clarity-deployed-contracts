(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-UNIT-NOT-FOUND (err u101))
(define-constant ERR-BATCH-NOT-FOUND (err u102))

(define-map production-batches
  { batch-id: uint }
  {
    bus-model: (string-ascii 50),
    target-quantity: uint,
    produced-quantity: uint,
    started-at: uint,
    completed-at: uint,
    status: (string-ascii 20),
    manufacturer: principal
  }
)

(define-map bus-units
  { batch-id: uint, unit-id: uint }
  {
    chassis-number: (string-ascii 30),
    battery-capacity: uint,
    motor-power: uint,
    assembly-stage: (string-ascii 30),
    quality-checked: bool,
    completed: bool
  }
)

(define-data-var batch-nonce uint u0)

(define-public (start-production-batch
  (bus-model (string-ascii 50))
  (target-quantity uint)
)
  (let ((batch-id (var-get batch-nonce)))
    (map-set production-batches
      { batch-id: batch-id }
      {
        bus-model: bus-model,
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

(define-public (add-bus-unit
  (batch-id uint)
  (unit-id uint)
  (chassis-number (string-ascii 30))
  (battery-capacity uint)
  (motor-power uint)
)
  (let ((batch (unwrap! (map-get? production-batches { batch-id: batch-id }) ERR-BATCH-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get manufacturer batch)) ERR-NOT-AUTHORIZED)
    (ok (map-set bus-units
      { batch-id: batch-id, unit-id: unit-id }
      {
        chassis-number: chassis-number,
        battery-capacity: battery-capacity,
        motor-power: motor-power,
        assembly-stage: "chassis",
        quality-checked: false,
        completed: false
      }
    ))
  )
)

(define-public (update-assembly-stage (batch-id uint) (unit-id uint) (new-stage (string-ascii 30)))
  (let (
    (batch (unwrap! (map-get? production-batches { batch-id: batch-id }) ERR-BATCH-NOT-FOUND))
    (unit (unwrap! (map-get? bus-units { batch-id: batch-id, unit-id: unit-id }) ERR-UNIT-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get manufacturer batch)) ERR-NOT-AUTHORIZED)
    (ok (map-set bus-units
      { batch-id: batch-id, unit-id: unit-id }
      (merge unit { assembly-stage: new-stage })
    ))
  )
)

(define-public (complete-quality-check (batch-id uint) (unit-id uint))
  (let (
    (batch (unwrap! (map-get? production-batches { batch-id: batch-id }) ERR-BATCH-NOT-FOUND))
    (unit (unwrap! (map-get? bus-units { batch-id: batch-id, unit-id: unit-id }) ERR-UNIT-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get manufacturer batch)) ERR-NOT-AUTHORIZED)
    (ok (map-set bus-units
      { batch-id: batch-id, unit-id: unit-id }
      (merge unit { quality-checked: true, completed: true })
    ))
  )
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

(define-read-only (get-batch-info (batch-id uint))
  (map-get? production-batches { batch-id: batch-id })
)

(define-read-only (get-unit-info (batch-id uint) (unit-id uint))
  (map-get? bus-units { batch-id: batch-id, unit-id: unit-id })
)
