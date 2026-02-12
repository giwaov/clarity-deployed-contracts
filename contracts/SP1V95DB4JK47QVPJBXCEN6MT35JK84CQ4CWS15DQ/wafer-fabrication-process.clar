(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-WAFER-NOT-FOUND (err u101))
(define-constant ERR-BATCH-NOT-FOUND (err u102))

(define-map wafer-batches
  { batch-id: uint }
  {
    wafer-size: uint,
    wafer-count: uint,
    process-node: uint,
    started-at: uint,
    completed-at: uint,
    status: (string-ascii 20),
    fab-operator: principal
  }
)

(define-map wafer-records
  { batch-id: uint, wafer-id: uint }
  {
    defect-count: uint,
    yield-rate: uint,
    quality-grade: (string-ascii 10),
    processing-time: uint,
    completed: bool
  }
)

(define-data-var batch-nonce uint u0)

(define-public (start-wafer-batch
  (wafer-size uint)
  (wafer-count uint)
  (process-node uint)
)
  (let ((batch-id (var-get batch-nonce)))
    (map-set wafer-batches
      { batch-id: batch-id }
      {
        wafer-size: wafer-size,
        wafer-count: wafer-count,
        process-node: process-node,
        started-at: stacks-block-height,
        completed-at: u0,
        status: "fabricating",
        fab-operator: tx-sender
      }
    )
    (var-set batch-nonce (+ batch-id u1))
    (ok batch-id)
  )
)

(define-public (add-wafer
  (batch-id uint)
  (wafer-id uint)
  (defect-count uint)
  (yield-rate uint)
  (quality-grade (string-ascii 10))
)
  (let ((batch (unwrap! (map-get? wafer-batches { batch-id: batch-id }) ERR-BATCH-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get fab-operator batch)) ERR-NOT-AUTHORIZED)
    (ok (map-set wafer-records
      { batch-id: batch-id, wafer-id: wafer-id }
      {
        defect-count: defect-count,
        yield-rate: yield-rate,
        quality-grade: quality-grade,
        processing-time: u0,
        completed: false
      }
    ))
  )
)

(define-public (complete-wafer (batch-id uint) (wafer-id uint) (processing-time uint))
  (let (
    (batch (unwrap! (map-get? wafer-batches { batch-id: batch-id }) ERR-BATCH-NOT-FOUND))
    (wafer (unwrap! (map-get? wafer-records { batch-id: batch-id, wafer-id: wafer-id }) ERR-WAFER-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get fab-operator batch)) ERR-NOT-AUTHORIZED)
    (ok (map-set wafer-records
      { batch-id: batch-id, wafer-id: wafer-id }
      (merge wafer { processing-time: processing-time, completed: true })
    ))
  )
)

(define-public (complete-batch (batch-id uint))
  (let ((batch (unwrap! (map-get? wafer-batches { batch-id: batch-id }) ERR-BATCH-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get fab-operator batch)) ERR-NOT-AUTHORIZED)
    (ok (map-set wafer-batches
      { batch-id: batch-id }
      (merge batch { status: "completed", completed-at: stacks-block-height })
    ))
  )
)

(define-read-only (get-batch-info (batch-id uint))
  (map-get? wafer-batches { batch-id: batch-id })
)

(define-read-only (get-wafer-info (batch-id uint) (wafer-id uint))
  (map-get? wafer-records { batch-id: batch-id, wafer-id: wafer-id })
)

(define-public (update-wafer-defects (batch-id uint) (wafer-id uint) (new-defect-count uint))
  (let (
    (batch (unwrap! (map-get? wafer-batches { batch-id: batch-id }) ERR-BATCH-NOT-FOUND))
    (wafer (unwrap! (map-get? wafer-records { batch-id: batch-id, wafer-id: wafer-id }) ERR-WAFER-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get fab-operator batch)) ERR-NOT-AUTHORIZED)
    (ok (map-set wafer-records
      { batch-id: batch-id, wafer-id: wafer-id }
      (merge wafer { defect-count: new-defect-count })
    ))
  )
)
