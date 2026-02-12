(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)
(define-data-var cto principal tx-sender)

(define-map tech-projects uint {name: (string-utf8 200), status: (string-ascii 20), budget: uint, start-block: uint, end-block: uint})
(define-map engineering-teams principal {team-name: (string-ascii 50), lead: principal, size: uint, active: bool})
(define-map infrastructure-resources (string-ascii 50) {resource-type: (string-ascii 30), allocated: uint, utilized: uint})
(define-map security-audits uint {auditor: principal, scope: (string-utf8 300), findings: uint, severity: (string-ascii 20), completed: bool})
(define-data-var project-count uint u0)
(define-data-var audit-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-cto) (var-get cto))

(define-read-only (get-tech-project (project-id uint))
  (map-get? tech-projects project-id))

(define-read-only (get-engineering-team (team-id principal))
  (map-get? engineering-teams team-id))

(define-read-only (get-infrastructure-resource (resource-id (string-ascii 50)))
  (map-get? infrastructure-resources resource-id))

(define-read-only (get-security-audit (audit-id uint))
  (map-get? security-audits audit-id))

(define-public (set-cto (new-cto principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set cto new-cto))))

(define-public (create-tech-project (name (string-utf8 200)) (budget uint) (duration uint))
  (let ((project-id (+ (var-get project-count) u1)))
    (asserts! (is-eq tx-sender (var-get cto)) ERR_UNAUTHORIZED)
    (asserts! (> budget u0) ERR_INVALID_PARAMS)
    (map-set tech-projects project-id {name: name, status: "planning", budget: budget, start-block: stacks-block-height, end-block: (+ stacks-block-height duration)})
    (var-set project-count project-id)
    (ok project-id)))

(define-public (update-project-status (project-id uint) (new-status (string-ascii 20)))
  (let ((project (unwrap! (map-get? tech-projects project-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get cto)) ERR_UNAUTHORIZED)
    (ok (map-set tech-projects project-id (merge project {status: new-status})))))

(define-public (create-engineering-team (team-id principal) (team-name (string-ascii 50)) (lead principal) (size uint))
  (begin
    (asserts! (is-eq tx-sender (var-get cto)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? engineering-teams team-id)) ERR_ALREADY_EXISTS)
    (asserts! (> size u0) ERR_INVALID_PARAMS)
    (ok (map-set engineering-teams team-id {team-name: team-name, lead: lead, size: size, active: true}))))

(define-public (update-team-size (team-id principal) (new-size uint))
  (let ((team (unwrap! (map-get? engineering-teams team-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get cto)) ERR_UNAUTHORIZED)
    (asserts! (> new-size u0) ERR_INVALID_PARAMS)
    (ok (map-set engineering-teams team-id (merge team {size: new-size})))))

(define-public (allocate-infrastructure (resource-id (string-ascii 50)) (resource-type (string-ascii 30)) (amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get cto)) ERR_UNAUTHORIZED)
    (asserts! (> amount u0) ERR_INVALID_PARAMS)
    (ok (map-set infrastructure-resources resource-id {resource-type: resource-type, allocated: amount, utilized: u0}))))

(define-public (update-resource-utilization (resource-id (string-ascii 50)) (utilized uint))
  (let ((resource (unwrap! (map-get? infrastructure-resources resource-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get cto)) ERR_UNAUTHORIZED)
    (asserts! (<= utilized (get allocated resource)) ERR_INVALID_PARAMS)
    (ok (map-set infrastructure-resources resource-id (merge resource {utilized: utilized})))))

(define-public (initiate-security-audit (auditor principal) (scope (string-utf8 300)))
  (let ((audit-id (+ (var-get audit-count) u1)))
    (asserts! (is-eq tx-sender (var-get cto)) ERR_UNAUTHORIZED)
    (map-set security-audits audit-id {auditor: auditor, scope: scope, findings: u0, severity: "pending", completed: false})
    (var-set audit-count audit-id)
    (ok audit-id)))

(define-public (complete-security-audit (audit-id uint) (findings uint) (severity (string-ascii 20)))
  (let ((audit (unwrap! (map-get? security-audits audit-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get cto)) ERR_UNAUTHORIZED)
    (asserts! (not (get completed audit)) ERR_ALREADY_EXISTS)
    (ok (map-set security-audits audit-id (merge audit {findings: findings, severity: severity, completed: true})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
