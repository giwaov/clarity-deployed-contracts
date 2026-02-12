(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map fraud-reports uint {hash: (buff 32), fraud-category: (string-ascii 50), program-affected: (string-ascii 100), estimated-loss: uint, timestamp: uint, status: (string-ascii 20)})
(define-map oig-agents principal {badge-number: (string-ascii 50), clearance: uint, active: bool})
(define-map recovery-actions {report-id: uint, agent: principal} {recovered-amount: uint, prosecution-recommended: bool})
(define-data-var fraud-report-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-fraud-report (report-id uint))
  (map-get? fraud-reports report-id))

(define-read-only (get-oig-agent (agent-id principal))
  (map-get? oig-agents agent-id))

(define-read-only (get-recovery-action (report-id uint) (agent principal))
  (map-get? recovery-actions {report-id: report-id, agent: agent}))

(define-public (report-fraud (content-hash (buff 32)) (fraud-category (string-ascii 50)) (program-affected (string-ascii 100)) (estimated-loss uint))
  (let ((report-id (+ (var-get fraud-report-count) u1)))
    (asserts! (> estimated-loss u0) ERR_INVALID_PARAMS)
    (map-set fraud-reports report-id {hash: content-hash, fraud-category: fraud-category, program-affected: program-affected, estimated-loss: estimated-loss, timestamp: stacks-block-height, status: "reported"})
    (var-set fraud-report-count report-id)
    (ok report-id)))

(define-public (register-oig-agent (agent principal) (badge-number (string-ascii 50)) (clearance uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? oig-agents agent)) ERR_ALREADY_EXISTS)
    (asserts! (<= clearance u5) ERR_INVALID_PARAMS)
    (ok (map-set oig-agents agent {badge-number: badge-number, clearance: clearance, active: true}))))

(define-public (record-recovery (report-id uint) (recovered-amount uint) (prosecution-recommended bool))
  (let ((agent-data (unwrap! (map-get? oig-agents tx-sender) ERR_UNAUTHORIZED)))
    (asserts! (is-some (map-get? fraud-reports report-id)) ERR_NOT_FOUND)
    (asserts! (get active agent-data) ERR_UNAUTHORIZED)
    (ok (map-set recovery-actions {report-id: report-id, agent: tx-sender} {recovered-amount: recovered-amount, prosecution-recommended: prosecution-recommended}))))

(define-public (update-report-status (report-id uint) (new-status (string-ascii 20)))
  (let ((report (unwrap! (map-get? fraud-reports report-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set fraud-reports report-id (merge report {status: new-status})))))

(define-public (deactivate-agent (agent principal))
  (let ((agent-data (unwrap! (map-get? oig-agents agent) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set oig-agents agent (merge agent-data {active: false})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
