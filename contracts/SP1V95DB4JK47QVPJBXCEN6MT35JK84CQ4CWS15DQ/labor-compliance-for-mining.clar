(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))

(define-map mining-operations-labor
  uint
  {
    operator: principal,
    location: (string-ascii 256),
    total-workers: uint,
    compliance-status: (string-ascii 32),
    last-audit: uint,
    certified: bool
  })

(define-map worker-records
  {operation-id: uint, worker: principal}
  {
    role: (string-ascii 64),
    hire-date: uint,
    safety-training: bool,
    work-hours: uint,
    wage-rate: uint
  })

(define-map compliance-audits
  {operation-id: uint, audit-id: uint}
  {auditor: principal, audit-date: uint, findings: (string-ascii 256), compliant: bool})

(define-data-var next-operation-id uint u0)

(define-read-only (get-operation (operation-id uint))
  (ok (map-get? mining-operations-labor operation-id)))

(define-public (register-operation (location (string-ascii 256)) (workers uint))
  (let ((operation-id (var-get next-operation-id)))
    (map-set mining-operations-labor operation-id
      {operator: tx-sender, location: location, total-workers: workers,
       compliance-status: "pending", last-audit: u0, certified: false})
    (var-set next-operation-id (+ operation-id u1))
    (ok operation-id)))

(define-public (add-worker (operation-id uint) (worker principal) (role (string-ascii 64)) (wage uint))
  (begin
    (asserts! (is-some (map-get? mining-operations-labor operation-id)) err-not-found)
    (ok (map-set worker-records {operation-id: operation-id, worker: worker}
      {role: role, hire-date: stacks-block-height, safety-training: false, work-hours: u0, wage-rate: wage}))))

(define-public (conduct-audit (operation-id uint) (audit-id uint) (findings (string-ascii 256)) (compliant bool))
  (let ((operation (unwrap! (map-get? mining-operations-labor operation-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set compliance-audits {operation-id: operation-id, audit-id: audit-id}
      {auditor: tx-sender, audit-date: stacks-block-height, findings: findings, compliant: compliant})
    (ok (map-set mining-operations-labor operation-id
      (merge operation {last-audit: stacks-block-height, certified: compliant})))))
