(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map ethics-reports uint {hash: (buff 32), violation-type: (string-ascii 50), severity: uint, timestamp: uint, confidential: bool, status: (string-ascii 20)})
(define-map compliance-officers principal {department: (string-ascii 50), certification: (string-ascii 100), active: bool})
(define-map remediation-plans {report-id: uint, officer: principal} {plan-hash: (buff 32), implemented: bool, completion-date: uint})
(define-data-var ethics-report-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-ethics-report (report-id uint))
  (map-get? ethics-reports report-id))

(define-read-only (get-compliance-officer (officer-id principal))
  (map-get? compliance-officers officer-id))

(define-read-only (get-remediation-plan (report-id uint) (officer principal))
  (map-get? remediation-plans {report-id: report-id, officer: officer}))

(define-public (submit-ethics-report (content-hash (buff 32)) (violation-type (string-ascii 50)) (severity uint) (confidential bool))
  (let ((report-id (+ (var-get ethics-report-count) u1)))
    (asserts! (<= severity u5) ERR_INVALID_PARAMS)
    (map-set ethics-reports report-id {hash: content-hash, violation-type: violation-type, severity: severity, timestamp: stacks-block-height, confidential: confidential, status: "open"})
    (var-set ethics-report-count report-id)
    (ok report-id)))

(define-public (register-compliance-officer (officer principal) (department (string-ascii 50)) (certification (string-ascii 100)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? compliance-officers officer)) ERR_ALREADY_EXISTS)
    (ok (map-set compliance-officers officer {department: department, certification: certification, active: true}))))

(define-public (create-remediation-plan (report-id uint) (plan-hash (buff 32)))
  (let ((officer-data (unwrap! (map-get? compliance-officers tx-sender) ERR_UNAUTHORIZED)))
    (asserts! (is-some (map-get? ethics-reports report-id)) ERR_NOT_FOUND)
    (asserts! (get active officer-data) ERR_UNAUTHORIZED)
    (ok (map-set remediation-plans {report-id: report-id, officer: tx-sender} {plan-hash: plan-hash, implemented: false, completion-date: u0}))))

(define-public (implement-remediation (report-id uint))
  (let ((plan (unwrap! (map-get? remediation-plans {report-id: report-id, officer: tx-sender}) ERR_NOT_FOUND)))
    (asserts! (is-some (map-get? compliance-officers tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (not (get implemented plan)) ERR_ALREADY_EXISTS)
    (ok (map-set remediation-plans {report-id: report-id, officer: tx-sender} (merge plan {implemented: true, completion-date: stacks-block-height})))))

(define-public (update-report-status (report-id uint) (new-status (string-ascii 20)))
  (let ((report (unwrap! (map-get? ethics-reports report-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set ethics-reports report-id (merge report {status: new-status})))))

(define-public (deactivate-officer (officer principal))
  (let ((officer-data (unwrap! (map-get? compliance-officers officer) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set compliance-officers officer (merge officer-data {active: false})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
