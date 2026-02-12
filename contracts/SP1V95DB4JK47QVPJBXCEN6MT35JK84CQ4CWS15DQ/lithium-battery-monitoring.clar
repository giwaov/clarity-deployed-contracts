(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-BATCH-NOT-FOUND (err u101))
(define-constant ERR-CELL-NOT-FOUND (err u102))

(define-map battery-batches
  { batch-id: uint }
  {
    battery-type: (string-ascii 30),
    target-cells: uint,
    produced-cells: uint,
    capacity-mah: uint,
    started-at: uint,
    completed-at: uint,
    status: (string-ascii 20),
    manufacturer: principal
  }
)

(define-map battery-cells
  { batch-id: uint, cell-id: uint }
  {
    voltage: uint,
    capacity: uint,
    temperature: uint,
    cycle-count: uint,
    quality-grade: (string-ascii 10),
    tested: bool
  }
)

(define-data-var batch-nonce uint u0)

(define-public (start-battery-batch
  (battery-type (string-ascii 30))
  (target-cells uint)
  (capacity-mah uint)
)
  (let ((batch-id (var-get batch-nonce)))
    (map-set battery-batches
      { batch-id: batch-id }
      {
        battery-type: battery-type,
        target-cells: target-cells,
        produced-cells: u0,
        capacity-mah: capacity-mah,
        started-at: stacks-block-height,
        completed-at: u0,
        status: "production",
        manufacturer: tx-sender
      }
    )
    (var-set batch-nonce (+ batch-id u1))
    (ok batch-id)
  )
)

(define-public (add-battery-cell
  (batch-id uint)
  (cell-id uint)
  (voltage uint)
  (capacity uint)
)
  (let ((batch (unwrap! (map-get? battery-batches { batch-id: batch-id }) ERR-BATCH-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get manufacturer batch)) ERR-NOT-AUTHORIZED)
    (ok (map-set battery-cells
      { batch-id: batch-id, cell-id: cell-id }
      {
        voltage: voltage,
        capacity: capacity,
        temperature: u0,
        cycle-count: u0,
        quality-grade: "pending",
        tested: false
      }
    ))
  )
)

(define-public (test-cell
  (batch-id uint)
  (cell-id uint)
  (temperature uint)
  (cycle-count uint)
  (quality-grade (string-ascii 10))
)
  (let (
    (batch (unwrap! (map-get? battery-batches { batch-id: batch-id }) ERR-BATCH-NOT-FOUND))
    (cell (unwrap! (map-get? battery-cells { batch-id: batch-id, cell-id: cell-id }) ERR-CELL-NOT-FOUND))
  )
    (asserts! (is-eq tx-sender (get manufacturer batch)) ERR-NOT-AUTHORIZED)
    (ok (map-set battery-cells
      { batch-id: batch-id, cell-id: cell-id }
      (merge cell {
        temperature: temperature,
        cycle-count: cycle-count,
        quality-grade: quality-grade,
        tested: true
      })
    ))
  )
)

(define-public (complete-batch (batch-id uint))
  (let ((batch (unwrap! (map-get? battery-batches { batch-id: batch-id }) ERR-BATCH-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get manufacturer batch)) ERR-NOT-AUTHORIZED)
    (ok (map-set battery-batches
      { batch-id: batch-id }
      (merge batch { status: "completed", completed-at: stacks-block-height })
    ))
  )
)

(define-read-only (get-batch-info (batch-id uint))
  (map-get? battery-batches { batch-id: batch-id })
)

(define-read-only (get-cell-info (batch-id uint) (cell-id uint))
  (map-get? battery-cells { batch-id: batch-id, cell-id: cell-id })
)

(define-public (update-produced-cells (batch-id uint) (new-count uint))
  (let ((batch (unwrap! (map-get? battery-batches { batch-id: batch-id }) ERR-BATCH-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get manufacturer batch)) ERR-NOT-AUTHORIZED)
    (ok (map-set battery-batches
      { batch-id: batch-id }
      (merge batch { produced-cells: new-count })
    ))
  )
)
