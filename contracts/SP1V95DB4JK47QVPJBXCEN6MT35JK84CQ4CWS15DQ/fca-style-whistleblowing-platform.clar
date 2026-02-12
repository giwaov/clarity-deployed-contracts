(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map fca-reports uint {hash: (buff 32), misconduct-type: (string-ascii 50), firm-reference: (string-ascii 100), impact-assessment: uint, timestamp: uint, protected: bool, status: (string-ascii 20)})
(define-map whistleblowers-registry principal {fca-registered: bool, reports-filed: uint, protection-granted: bool})
(define-map regulatory-outcomes {report-id: uint, regulator: principal} {outcome-type: (string-ascii 50), penalty: uint, published: bool})
(define-data-var fca-report-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-fca-report (report-id uint))
  (map-get? fca-reports report-id))

(define-read-only (get-whistleblower-registry (whistleblower-id principal))
  (map-get? whistleblowers-registry whistleblower-id))

(define-read-only (get-regulatory-outcome (report-id uint) (regulator principal))
  (map-get? regulatory-outcomes {report-id: report-id, regulator: regulator}))

(define-public (file-fca-report (content-hash (buff 32)) (misconduct-type (string-ascii 50)) (firm-reference (string-ascii 100)) (impact-assessment uint))
  (let ((report-id (+ (var-get fca-report-count) u1))
        (whistleblower-data (default-to {fca-registered: false, reports-filed: u0, protection-granted: false} (map-get? whistleblowers-registry tx-sender))))
    (asserts! (<= impact-assessment u10) ERR_INVALID_PARAMS)
    (map-set fca-reports report-id {hash: content-hash, misconduct-type: misconduct-type, firm-reference: firm-reference, impact-assessment: impact-assessment, timestamp: stacks-block-height, protected: true, status: "filed"})
    (map-set whistleblowers-registry tx-sender (merge whistleblower-data {fca-registered: true, reports-filed: (+ (get reports-filed whistleblower-data) u1), protection-granted: true}))
    (var-set fca-report-count report-id)
    (ok report-id)))

(define-public (grant-protection (whistleblower principal))
  (let ((whistleblower-data (default-to {fca-registered: false, reports-filed: u0, protection-granted: false} (map-get? whistleblowers-registry whistleblower))))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set whistleblowers-registry whistleblower (merge whistleblower-data {protection-granted: true})))))

(define-public (record-regulatory-outcome (report-id uint) (outcome-type (string-ascii 50)) (penalty uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? fca-reports report-id)) ERR_NOT_FOUND)
    (ok (map-set regulatory-outcomes {report-id: report-id, regulator: tx-sender} {outcome-type: outcome-type, penalty: penalty, published: false}))))

(define-public (publish-outcome (report-id uint))
  (let ((outcome (unwrap! (map-get? regulatory-outcomes {report-id: report-id, regulator: tx-sender}) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set regulatory-outcomes {report-id: report-id, regulator: tx-sender} (merge outcome {published: true})))))

(define-public (update-report-status (report-id uint) (new-status (string-ascii 20)))
  (let ((report (unwrap! (map-get? fca-reports report-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set fca-reports report-id (merge report {status: new-status})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
