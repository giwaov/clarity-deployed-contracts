(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map complaints uint {hash: (buff 32), complaint-type: (string-ascii 50), severity: uint, timestamp: uint, status: (string-ascii 20)})
(define-map legal-officers principal {jurisdiction: (string-ascii 50), bar-number: (string-ascii 50), active: bool})
(define-map case-reviews {complaint-id: uint, officer: principal} {reviewed-at: uint, action-taken: (string-ascii 100)})
(define-data-var complaint-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-complaint (complaint-id uint))
  (map-get? complaints complaint-id))

(define-read-only (get-legal-officer (officer-id principal))
  (map-get? legal-officers officer-id))

(define-read-only (get-case-review (complaint-id uint) (officer principal))
  (map-get? case-reviews {complaint-id: complaint-id, officer: officer}))

(define-public (file-complaint (content-hash (buff 32)) (complaint-type (string-ascii 50)) (severity uint))
  (let ((complaint-id (+ (var-get complaint-count) u1)))
    (asserts! (<= severity u5) ERR_INVALID_PARAMS)
    (map-set complaints complaint-id {hash: content-hash, complaint-type: complaint-type, severity: severity, timestamp: stacks-block-height, status: "filed"})
    (var-set complaint-count complaint-id)
    (ok complaint-id)))

(define-public (register-legal-officer (officer principal) (jurisdiction (string-ascii 50)) (bar-number (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? legal-officers officer)) ERR_ALREADY_EXISTS)
    (ok (map-set legal-officers officer {jurisdiction: jurisdiction, bar-number: bar-number, active: true}))))

(define-public (review-case (complaint-id uint) (action-taken (string-ascii 100)))
  (let ((officer-data (unwrap! (map-get? legal-officers tx-sender) ERR_UNAUTHORIZED)))
    (asserts! (is-some (map-get? complaints complaint-id)) ERR_NOT_FOUND)
    (asserts! (get active officer-data) ERR_UNAUTHORIZED)
    (ok (map-set case-reviews {complaint-id: complaint-id, officer: tx-sender} {reviewed-at: stacks-block-height, action-taken: action-taken}))))

(define-public (update-complaint-status (complaint-id uint) (new-status (string-ascii 20)))
  (let ((complaint (unwrap! (map-get? complaints complaint-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set complaints complaint-id (merge complaint {status: new-status})))))

(define-public (deactivate-officer (officer principal))
  (let ((officer-data (unwrap! (map-get? legal-officers officer) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set legal-officers officer (merge officer-data {active: false})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
