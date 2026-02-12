(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-not-authorized (err u102))

(define-map export-licenses
  uint
  {
    exporter: principal,
    destination-country: (string-ascii 64),
    rare-earth-element: (string-ascii 64),
    quantity-tonnes: uint,
    end-use: (string-ascii 128),
    issue-date: uint,
    expiry-date: uint,
    approved: bool
  })

(define-map controlled-elements
  (string-ascii 64)
  {control-level: (string-ascii 32), export-restricted: bool, license-required: bool})

(define-map compliance-checks
  {license-id: uint, check-id: uint}
  {check-date: uint, compliance-officer: principal, status: (string-ascii 32), notes: (string-ascii 256)})

(define-data-var next-license-id uint u0)

(define-read-only (get-export-license (license-id uint))
  (ok (map-get? export-licenses license-id)))

(define-read-only (get-element-controls (element (string-ascii 64)))
  (ok (map-get? controlled-elements element)))

(define-public (apply-for-export-license (country (string-ascii 64)) (element (string-ascii 64)) (quantity uint) (end-use (string-ascii 128)) (duration uint))
  (let ((license-id (var-get next-license-id)))
    (map-set export-licenses license-id
      {exporter: tx-sender, destination-country: country, rare-earth-element: element,
       quantity-tonnes: quantity, end-use: end-use, issue-date: stacks-block-height,
       expiry-date: (+ stacks-block-height duration), approved: false})
    (var-set next-license-id (+ license-id u1))
    (ok license-id)))

(define-public (approve-export-license (license-id uint))
  (let ((license (unwrap! (map-get? export-licenses license-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set export-licenses license-id (merge license {approved: true})))))

(define-public (set-element-controls (element (string-ascii 64)) (level (string-ascii 32)) (restricted bool) (license-req bool))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set controlled-elements element
      {control-level: level, export-restricted: restricted, license-required: license-req}))))

(define-public (perform-compliance-check (license-id uint) (check-id uint) (status (string-ascii 32)) (notes (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set compliance-checks {license-id: license-id, check-id: check-id}
      {check-date: stacks-block-height, compliance-officer: tx-sender, status: status, notes: notes}))))
