(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-TEST-NOT-FOUND (err u101))
(define-constant ERR-BATCH-NOT-FOUND (err u102))

(define-map test-batches
  { batch-id: uint }
  {
    chip-type: (string-ascii 50),
    total-chips: uint,
    tested-chips: uint,
    passed-chips: uint,
    started-at: uint,
    completed-at: uint,
    status: (string-ascii 20),
    test-operator: principal
  }
)

(define-map chip-test-results
  { batch-id: uint, chip-id: uint }
  {
    voltage-test: bool,
    frequency-test: bool,
    temperature-test: bool,
    power-consumption-test: bool,
    overall-pass: bool,
    tested-at: uint
  }
)

(define-data-var batch-nonce uint u0)

(define-public (start-test-batch
  (chip-type (string-ascii 50))
  (total-chips uint)
)
  (let ((batch-id (var-get batch-nonce)))
    (map-set test-batches
      { batch-id: batch-id }
      {
        chip-type: chip-type,
        total-chips: total-chips,
        tested-chips: u0,
        passed-chips: u0,
        started-at: stacks-block-height,
        completed-at: u0,
        status: "testing",
        test-operator: tx-sender
      }
    )
    (var-set batch-nonce (+ batch-id u1))
    (ok batch-id)
  )
)

(define-public (test-chip
  (batch-id uint)
  (chip-id uint)
  (voltage-pass bool)
  (frequency-pass bool)
  (temp-pass bool)
  (power-pass bool)
)
  (let (
    (batch (unwrap! (map-get? test-batches { batch-id: batch-id }) ERR-BATCH-NOT-FOUND))
    (overall-pass (and (and voltage-pass frequency-pass) (and temp-pass power-pass)))
  )
    (asserts! (is-eq tx-sender (get test-operator batch)) ERR-NOT-AUTHORIZED)
    (map-set chip-test-results
      { batch-id: batch-id, chip-id: chip-id }
      {
        voltage-test: voltage-pass,
        frequency-test: frequency-pass,
        temperature-test: temp-pass,
        power-consumption-test: power-pass,
        overall-pass: overall-pass,
        tested-at: stacks-block-height
      }
    )
    (ok (map-set test-batches
      { batch-id: batch-id }
      (merge batch {
        tested-chips: (+ (get tested-chips batch) u1),
        passed-chips: (if overall-pass (+ (get passed-chips batch) u1) (get passed-chips batch))
      })
    ))
  )
)

(define-public (complete-testing (batch-id uint))
  (let ((batch (unwrap! (map-get? test-batches { batch-id: batch-id }) ERR-BATCH-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get test-operator batch)) ERR-NOT-AUTHORIZED)
    (ok (map-set test-batches
      { batch-id: batch-id }
      (merge batch { status: "completed", completed-at: stacks-block-height })
    ))
  )
)

(define-read-only (get-batch-info (batch-id uint))
  (map-get? test-batches { batch-id: batch-id })
)

(define-read-only (get-test-result (batch-id uint) (chip-id uint))
  (map-get? chip-test-results { batch-id: batch-id, chip-id: chip-id })
)

(define-public (update-batch-status (batch-id uint) (new-status (string-ascii 20)))
  (let ((batch (unwrap! (map-get? test-batches { batch-id: batch-id }) ERR-BATCH-NOT-FOUND)))
    (asserts! (is-eq tx-sender (get test-operator batch)) ERR-NOT-AUTHORIZED)
    (ok (map-set test-batches
      { batch-id: batch-id }
      (merge batch { status: new-status })
    ))
  )
)
