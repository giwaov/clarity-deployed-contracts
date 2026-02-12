(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map misconduct-reports uint {hash: (buff 32), report-type: (string-ascii 50), severity: uint, timestamp: uint, anonymous: bool, investigated: bool, status: (string-ascii 20)})
(define-map case-managers principal {manager-name: (string-ascii 100), department: (string-ascii 50), cases-handled: uint, active: bool})
(define-map investigation-logs {report-id: uint, manager: principal} {log-hash: (buff 32), evidence-count: uint, outcome: (string-ascii 100), closed: bool})
(define-data-var misconduct-report-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-misconduct-report (report-id uint))
  (map-get? misconduct-reports report-id))

(define-read-only (get-case-manager (manager-id principal))
  (map-get? case-managers manager-id))

(define-read-only (get-investigation-log (report-id uint) (manager principal))
  (map-get? investigation-logs {report-id: report-id, manager: manager}))

(define-public (file-misconduct-report (content-hash (buff 32)) (report-type (string-ascii 50)) (severity uint) (anonymous bool))
  (let ((report-id (+ (var-get misconduct-report-count) u1)))
    (asserts! (<= severity u5) ERR_INVALID_PARAMS)
    (map-set misconduct-reports report-id {hash: content-hash, report-type: report-type, severity: severity, timestamp: stacks-block-height, anonymous: anonymous, investigated: false, status: "filed"})
    (var-set misconduct-report-count report-id)
    (ok report-id)))

(define-public (assign-case-manager (manager principal) (manager-name (string-ascii 100)) (department (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? case-managers manager)) ERR_ALREADY_EXISTS)
    (ok (map-set case-managers manager {manager-name: manager-name, department: department, cases-handled: u0, active: true}))))

(define-public (investigate-report (report-id uint) (log-hash (buff 32)) (evidence-count uint))
  (let ((manager-data (unwrap! (map-get? case-managers tx-sender) ERR_UNAUTHORIZED))
        (report (unwrap! (map-get? misconduct-reports report-id) ERR_NOT_FOUND)))
    (asserts! (get active manager-data) ERR_UNAUTHORIZED)
    (map-set case-managers tx-sender (merge manager-data {cases-handled: (+ (get cases-handled manager-data) u1)}))
    (map-set misconduct-reports report-id (merge report {investigated: true}))
    (ok (map-set investigation-logs {report-id: report-id, manager: tx-sender} {log-hash: log-hash, evidence-count: evidence-count, outcome: "", closed: false}))))

(define-public (close-investigation (report-id uint) (outcome (string-ascii 100)))
  (let ((log (unwrap! (map-get? investigation-logs {report-id: report-id, manager: tx-sender}) ERR_NOT_FOUND)))
    (asserts! (is-some (map-get? case-managers tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (not (get closed log)) ERR_ALREADY_EXISTS)
    (ok (map-set investigation-logs {report-id: report-id, manager: tx-sender} (merge log {outcome: outcome, closed: true})))))

(define-public (update-report-status (report-id uint) (new-status (string-ascii 20)))
  (let ((report (unwrap! (map-get? misconduct-reports report-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set misconduct-reports report-id (merge report {status: new-status})))))

(define-public (deactivate-manager (manager principal))
  (let ((manager-data (unwrap! (map-get? case-managers manager) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set case-managers manager (merge manager-data {active: false})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
