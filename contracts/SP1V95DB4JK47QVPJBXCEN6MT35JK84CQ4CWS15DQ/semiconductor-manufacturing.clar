(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-PROCESS-NOT-FOUND (err u101))
(define-constant ERR-INVALID-STATUS (err u102))

(define-map manufacturing-processes
  { process-id: uint }
  {
    chip-type: (string-ascii 50),
    node-size: uint,
    wafer-count: uint,
    started-at: uint,
    completed-at: uint,
    status: (string-ascii 20),
    operator: principal
  }
)

(define-map production-steps
  { process-id: uint, step-id: uint }
  {
    step-name: (string-ascii 50),
    duration: uint,
    completed: bool,
    quality-score: uint
  }
)

(define-data-var process-nonce uint u0)

(define-public (start-manufacturing
  (chip-type (string-ascii 50))
  (node-size uint)
  (wafer-count uint)
)
  (let ((process-id (var-get process-nonce)))
    (map-set manufacturing-processes
      { process-id: process-id }
      {
        chip-type: chip-type,
        node-size: node-size,
        wafer-count: wafer-count,
        started-at: stacks-block-height,
        completed-at: u0,
        status: "in-progress",
        operator: tx-sender
      }
    )
    (var-set process-nonce (+ process-id u1))
    (ok process-id)
  )
)

(define-public (add-production-step
  (process-id uint)
  (step-id uint)
  (step-name (string-ascii 50))
  (duration uint)
)
  (let ((process (unwrap! (map-get? manufacturing-processes { process-id: process-id }) ERR-PROCESS-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get operator process)) ERR-NOT-AUTHORIZED)
    (ok (map-set production-steps
      { process-id: process-id, step-id: step-id }
      {
        step-name: step-name,
        duration: duration,
        completed: false,
        quality-score: u0
      }
    ))
  )
)

(define-public (complete-step (process-id uint) (step-id uint) (quality-score uint))
  (let (
    (process (unwrap! (map-get? manufacturing-processes { process-id: process-id }) ERR-PROCESS-NOT-FOUND))
    (step (unwrap! (map-get? production-steps { process-id: process-id, step-id: step-id }) ERR-PROCESS-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get operator process)) ERR-NOT-AUTHORIZED)
    (ok (map-set production-steps
      { process-id: process-id, step-id: step-id }
      (merge step { completed: true, quality-score: quality-score })
    ))
  )
)

(define-public (complete-manufacturing (process-id uint))
  (let ((process (unwrap! (map-get? manufacturing-processes { process-id: process-id }) ERR-PROCESS-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get operator process)) ERR-NOT-AUTHORIZED)
    (ok (map-set manufacturing-processes
      { process-id: process-id }
      (merge process { status: "completed", completed-at: stacks-block-height })
    ))
  )
)

(define-read-only (get-process-info (process-id uint))
  (map-get? manufacturing-processes { process-id: process-id })
)

(define-read-only (get-step-info (process-id uint) (step-id uint))
  (map-get? production-steps { process-id: process-id, step-id: step-id })
)

(define-public (update-wafer-count (process-id uint) (new-count uint))
  (let ((process (unwrap! (map-get? manufacturing-processes { process-id: process-id }) ERR-PROCESS-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get operator process)) ERR-NOT-AUTHORIZED)
    (ok (map-set manufacturing-processes
      { process-id: process-id }
      (merge process { wafer-count: new-count })
    ))
  )
)
