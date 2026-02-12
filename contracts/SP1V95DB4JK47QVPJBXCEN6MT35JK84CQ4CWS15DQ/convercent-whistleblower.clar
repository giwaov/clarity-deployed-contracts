(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map incident-reports uint {hash: (buff 32), category: (string-ascii 50), priority: uint, timestamp: uint, escalated: bool, status: (string-ascii 20)})
(define-map ethics-teams principal {team-name: (string-ascii 100), lead: principal, active: bool})
(define-map corrective-actions {report-id: uint, team: principal} {action-hash: (buff 32), approved: bool, executed: bool})
(define-data-var incident-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-incident-report (report-id uint))
  (map-get? incident-reports report-id))

(define-read-only (get-ethics-team (team-id principal))
  (map-get? ethics-teams team-id))

(define-read-only (get-corrective-action (report-id uint) (team principal))
  (map-get? corrective-actions {report-id: report-id, team: team}))

(define-public (report-incident (content-hash (buff 32)) (category (string-ascii 50)) (priority uint))
  (let ((incident-id (+ (var-get incident-count) u1)))
    (asserts! (<= priority u5) ERR_INVALID_PARAMS)
    (map-set incident-reports incident-id {hash: content-hash, category: category, priority: priority, timestamp: stacks-block-height, escalated: false, status: "reported"})
    (var-set incident-count incident-id)
    (ok incident-id)))

(define-public (register-ethics-team (team-id principal) (team-name (string-ascii 100)) (lead principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? ethics-teams team-id)) ERR_ALREADY_EXISTS)
    (ok (map-set ethics-teams team-id {team-name: team-name, lead: lead, active: true}))))

(define-public (escalate-incident (incident-id uint))
  (let ((incident (unwrap! (map-get? incident-reports incident-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (not (get escalated incident)) ERR_ALREADY_EXISTS)
    (ok (map-set incident-reports incident-id (merge incident {escalated: true})))))

(define-public (propose-corrective-action (report-id uint) (action-hash (buff 32)))
  (let ((team-data (unwrap! (map-get? ethics-teams tx-sender) ERR_UNAUTHORIZED)))
    (asserts! (is-some (map-get? incident-reports report-id)) ERR_NOT_FOUND)
    (asserts! (get active team-data) ERR_UNAUTHORIZED)
    (ok (map-set corrective-actions {report-id: report-id, team: tx-sender} {action-hash: action-hash, approved: false, executed: false}))))

(define-public (approve-action (report-id uint) (team principal))
  (let ((action (unwrap! (map-get? corrective-actions {report-id: report-id, team: team}) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set corrective-actions {report-id: report-id, team: team} (merge action {approved: true})))))

(define-public (execute-action (report-id uint))
  (let ((action (unwrap! (map-get? corrective-actions {report-id: report-id, team: tx-sender}) ERR_NOT_FOUND)))
    (asserts! (get approved action) ERR_UNAUTHORIZED)
    (asserts! (not (get executed action)) ERR_ALREADY_EXISTS)
    (ok (map-set corrective-actions {report-id: report-id, team: tx-sender} (merge action {executed: true})))))

(define-public (update-incident-status (incident-id uint) (new-status (string-ascii 20)))
  (let ((incident (unwrap! (map-get? incident-reports incident-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set incident-reports incident-id (merge incident {status: new-status})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
