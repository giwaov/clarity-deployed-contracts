(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map reports uint {hash: (buff 32), category: (string-ascii 50), severity: uint, timestamp: uint, anonymous: bool, status: (string-ascii 20)})
(define-map receivers principal {organization: (string-ascii 100), role: (string-ascii 50), verified: bool, active: bool})
(define-map case-assignments {report-id: uint, receiver: principal} {assigned-at: uint, reviewed: bool})
(define-data-var report-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-report (report-id uint))
  (map-get? reports report-id))

(define-read-only (get-receiver (receiver-id principal))
  (map-get? receivers receiver-id))

(define-read-only (get-assignment (report-id uint) (receiver principal))
  (map-get? case-assignments {report-id: report-id, receiver: receiver}))

(define-public (file-report (content-hash (buff 32)) (category (string-ascii 50)) (severity uint) (anonymous bool))
  (let ((report-id (+ (var-get report-count) u1)))
    (asserts! (<= severity u5) ERR_INVALID_PARAMS)
    (map-set reports report-id {hash: content-hash, category: category, severity: severity, timestamp: stacks-block-height, anonymous: anonymous, status: "submitted"})
    (var-set report-count report-id)
    (ok report-id)))

(define-public (register-receiver (receiver principal) (organization (string-ascii 100)) (role (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? receivers receiver)) ERR_ALREADY_EXISTS)
    (ok (map-set receivers receiver {organization: organization, role: role, verified: true, active: true}))))

(define-public (assign-case (report-id uint) (receiver principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? reports report-id)) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? receivers receiver)) ERR_NOT_FOUND)
    (ok (map-set case-assignments {report-id: report-id, receiver: receiver} {assigned-at: stacks-block-height, reviewed: false}))))

(define-public (mark-reviewed (report-id uint))
  (let ((receiver-data (unwrap! (map-get? receivers tx-sender) ERR_UNAUTHORIZED))
        (assignment (unwrap! (map-get? case-assignments {report-id: report-id, receiver: tx-sender}) ERR_NOT_FOUND)))
    (asserts! (get active receiver-data) ERR_UNAUTHORIZED)
    (ok (map-set case-assignments {report-id: report-id, receiver: tx-sender} (merge assignment {reviewed: true})))))

(define-public (update-report-status (report-id uint) (new-status (string-ascii 20)))
  (let ((report (unwrap! (map-get? reports report-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set reports report-id (merge report {status: new-status})))))

(define-public (deactivate-receiver (receiver principal))
  (let ((receiver-data (unwrap! (map-get? receivers receiver) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set receivers receiver (merge receiver-data {active: false})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
