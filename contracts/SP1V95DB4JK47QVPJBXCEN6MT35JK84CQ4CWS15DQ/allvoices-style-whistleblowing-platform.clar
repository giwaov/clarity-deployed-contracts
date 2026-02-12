(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map workplace-issues uint {hash: (buff 32), issue-type: (string-ascii 50), department: (string-ascii 100), priority: uint, timestamp: uint, resolved: bool})
(define-map employees principal {employee-id: (string-ascii 50), verified: bool, issues-reported: uint})
(define-map hr-responses {issue-id: uint, hr-rep: principal} {response-hash: (buff 32), action-taken: (string-ascii 200), completion-date: uint})
(define-data-var issue-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-workplace-issue (issue-id uint))
  (map-get? workplace-issues issue-id))

(define-read-only (get-employee (employee-id principal))
  (map-get? employees employee-id))

(define-read-only (get-hr-response (issue-id uint) (hr-rep principal))
  (map-get? hr-responses {issue-id: issue-id, hr-rep: hr-rep}))

(define-public (report-workplace-issue (content-hash (buff 32)) (issue-type (string-ascii 50)) (department (string-ascii 100)) (priority uint))
  (let ((issue-id (+ (var-get issue-count) u1))
        (employee-data (default-to {employee-id: "", verified: false, issues-reported: u0} (map-get? employees tx-sender))))
    (asserts! (<= priority u5) ERR_INVALID_PARAMS)
    (map-set workplace-issues issue-id {hash: content-hash, issue-type: issue-type, department: department, priority: priority, timestamp: stacks-block-height, resolved: false})
    (map-set employees tx-sender (merge employee-data {issues-reported: (+ (get issues-reported employee-data) u1)}))
    (var-set issue-count issue-id)
    (ok issue-id)))

(define-public (verify-employee (employee principal) (employee-id (string-ascii 50)))
  (let ((employee-data (default-to {employee-id: "", verified: false, issues-reported: u0} (map-get? employees employee))))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set employees employee (merge employee-data {employee-id: employee-id, verified: true})))))

(define-public (respond-to-issue (issue-id uint) (response-hash (buff 32)) (action-taken (string-ascii 200)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? workplace-issues issue-id)) ERR_NOT_FOUND)
    (ok (map-set hr-responses {issue-id: issue-id, hr-rep: tx-sender} {response-hash: response-hash, action-taken: action-taken, completion-date: u0}))))

(define-public (close-issue (issue-id uint))
  (let ((issue (unwrap! (map-get? workplace-issues issue-id) ERR_NOT_FOUND))
        (response (unwrap! (map-get? hr-responses {issue-id: issue-id, hr-rep: tx-sender}) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (not (get resolved issue)) ERR_ALREADY_EXISTS)
    (map-set hr-responses {issue-id: issue-id, hr-rep: tx-sender} (merge response {completion-date: stacks-block-height}))
    (ok (map-set workplace-issues issue-id (merge issue {resolved: true})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
