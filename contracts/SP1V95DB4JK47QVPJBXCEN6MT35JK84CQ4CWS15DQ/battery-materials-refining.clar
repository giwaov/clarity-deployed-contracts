(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map refining-facilities
  uint
  {
    operator: principal,
    location: (string-ascii 128),
    input-material: (string-ascii 64),
    output-material: (string-ascii 64),
    processing-capacity: uint,
    certified: bool
  })

(define-map refining-batches
  uint
  {
    facility-id: uint,
    input-quantity: uint,
    output-quantity: uint,
    output-purity: uint,
    start-date: uint,
    completion-date: uint,
    status: (string-ascii 32)
  })

(define-data-var next-facility-id uint u0)
(define-data-var next-batch-id uint u0)

(define-read-only (get-facility (facility-id uint))
  (ok (map-get? refining-facilities facility-id)))

(define-public (register-facility (location (string-ascii 128)) (input (string-ascii 64)) (output (string-ascii 64)) (capacity uint))
  (let ((facility-id (var-get next-facility-id)))
    (map-set refining-facilities facility-id
      {operator: tx-sender, location: location, input-material: input,
       output-material: output, processing-capacity: capacity, certified: false})
    (var-set next-facility-id (+ facility-id u1))
    (ok facility-id)))

(define-public (process-batch (facility-id uint) (input-qty uint) (output-qty uint) (purity uint))
  (let ((batch-id (var-get next-batch-id)))
    (asserts! (is-some (map-get? refining-facilities facility-id)) err-not-found)
    (map-set refining-batches batch-id
      {facility-id: facility-id, input-quantity: input-qty, output-quantity: output-qty,
       output-purity: purity, start-date: stacks-block-height, completion-date: u0, status: "processing"})
    (var-set next-batch-id (+ batch-id u1))
    (ok batch-id)))

(define-public (complete-batch (batch-id uint))
  (let ((batch (unwrap! (map-get? refining-batches batch-id) err-not-found)))
    (ok (map-set refining-batches batch-id
      (merge batch {completion-date: stacks-block-height, status: "completed"})))))
