(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-license-expired (err u102))

(define-map mining-licenses
  uint
  {
    holder: principal,
    site-location: (string-ascii 256),
    license-type: (string-ascii 64),
    issue-date: uint,
    expiry-date: uint,
    production-limit: uint,
    environmental-approval: bool,
    active: bool
  })

(define-map license-renewals
  {license-id: uint, renewal-id: uint}
  {request-date: uint, new-expiry: uint, approved: bool})

(define-data-var next-license-id uint u0)

(define-read-only (get-license (license-id uint))
  (ok (map-get? mining-licenses license-id)))

(define-public (apply-for-license (location (string-ascii 256)) (type (string-ascii 64)) (duration uint) (limit uint))
  (let ((license-id (var-get next-license-id)))
    (map-set mining-licenses license-id
      {holder: tx-sender, site-location: location, license-type: type,
       issue-date: stacks-block-height, expiry-date: (+ stacks-block-height duration),
       production-limit: limit, environmental-approval: false, active: false})
    (var-set next-license-id (+ license-id u1))
    (ok license-id)))

(define-public (approve-license (license-id uint))
  (let ((license (unwrap! (map-get? mining-licenses license-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set mining-licenses license-id
      (merge license {environmental-approval: true, active: true})))))

(define-public (renew-license (license-id uint) (renewal-id uint) (extension uint))
  (let ((license (unwrap! (map-get? mining-licenses license-id) err-not-found)))
    (asserts! (is-eq tx-sender (get holder license)) err-owner-only)
    (ok (map-set license-renewals {license-id: license-id, renewal-id: renewal-id}
      {request-date: stacks-block-height, new-expiry: (+ (get expiry-date license) extension), approved: false}))))
