(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map metallurgy-processes
  uint
  {
    facility: principal,
    input-ore: (string-ascii 64),
    process-type: (string-ascii 64),
    output-purity: uint,
    batch-size: uint,
    start-block: uint,
    completed: bool
  })

(define-map quality-certifications
  {process-id: uint, certification-type: (string-ascii 64)}
  {certified-by: principal, purity-level: uint, certification-date: uint})

(define-data-var next-process-id uint u0)

(define-read-only (get-process (process-id uint))
  (ok (map-get? metallurgy-processes process-id)))

(define-public (start-process (ore (string-ascii 64)) (process (string-ascii 64)) (purity uint) (batch uint))
  (let ((process-id (var-get next-process-id)))
    (map-set metallurgy-processes process-id
      {facility: tx-sender, input-ore: ore, process-type: process,
       output-purity: purity, batch-size: batch, start-block: stacks-block-height, completed: false})
    (var-set next-process-id (+ process-id u1))
    (ok process-id)))

(define-public (complete-process (process-id uint))
  (let ((process (unwrap! (map-get? metallurgy-processes process-id) err-not-found)))
    (asserts! (is-eq tx-sender (get facility process)) err-owner-only)
    (ok (map-set metallurgy-processes process-id (merge process {completed: true})))))

(define-public (certify-quality (process-id uint) (cert-type (string-ascii 64)) (purity uint))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set quality-certifications {process-id: process-id, certification-type: cert-type}
      {certified-by: tx-sender, purity-level: purity, certification-date: stacks-block-height}))))
