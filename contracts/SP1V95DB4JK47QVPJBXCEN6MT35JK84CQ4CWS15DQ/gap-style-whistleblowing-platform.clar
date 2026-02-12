(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map anonymous-reports uint {hash: (buff 32), category: (string-ascii 50), priority: uint, timestamp: uint, resolved: bool})
(define-map investigators principal {clearance-level: uint, active: bool})
(define-map investigation-notes {report-id: uint, investigator: principal} {note-hash: (buff 32), added-at: uint})
(define-data-var report-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-anonymous-report (report-id uint))
  (map-get? anonymous-reports report-id))

(define-read-only (get-investigator (investigator-id principal))
  (map-get? investigators investigator-id))

(define-read-only (get-investigation-note (report-id uint) (investigator principal))
  (map-get? investigation-notes {report-id: report-id, investigator: investigator}))

(define-public (submit-anonymous-report (content-hash (buff 32)) (category (string-ascii 50)) (priority uint))
  (let ((report-id (+ (var-get report-count) u1)))
    (asserts! (<= priority u5) ERR_INVALID_PARAMS)
    (map-set anonymous-reports report-id {hash: content-hash, category: category, priority: priority, timestamp: stacks-block-height, resolved: false})
    (var-set report-count report-id)
    (ok report-id)))

(define-public (register-investigator (investigator principal) (clearance-level uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? investigators investigator)) ERR_ALREADY_EXISTS)
    (asserts! (<= clearance-level u5) ERR_INVALID_PARAMS)
    (ok (map-set investigators investigator {clearance-level: clearance-level, active: true}))))

(define-public (add-investigation-note (report-id uint) (note-hash (buff 32)))
  (let ((investigator-data (unwrap! (map-get? investigators tx-sender) ERR_UNAUTHORIZED)))
    (asserts! (is-some (map-get? anonymous-reports report-id)) ERR_NOT_FOUND)
    (asserts! (get active investigator-data) ERR_UNAUTHORIZED)
    (ok (map-set investigation-notes {report-id: report-id, investigator: tx-sender} {note-hash: note-hash, added-at: stacks-block-height}))))

(define-public (resolve-report (report-id uint))
  (let ((report (unwrap! (map-get? anonymous-reports report-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (not (get resolved report)) ERR_ALREADY_EXISTS)
    (ok (map-set anonymous-reports report-id (merge report {resolved: true})))))

(define-public (update-priority (report-id uint) (new-priority uint))
  (let ((report (unwrap! (map-get? anonymous-reports report-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (<= new-priority u5) ERR_INVALID_PARAMS)
    (ok (map-set anonymous-reports report-id (merge report {priority: new-priority})))))

(define-public (deactivate-investigator (investigator principal))
  (let ((investigator-data (unwrap! (map-get? investigators investigator) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set investigators investigator (merge investigator-data {active: false})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
