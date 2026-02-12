(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map finra-tips uint {hash: (buff 32), violation-type: (string-ascii 50), firm-involved: (string-ascii 100), monetary-harm: uint, timestamp: uint, status: (string-ascii 20)})
(define-map certified-informants principal {registration-number: (string-ascii 50), verified: bool, tips-submitted: uint})
(define-map enforcement-actions {tip-id: uint, enforcer: principal} {action-type: (string-ascii 50), fine-amount: uint, completed: bool})
(define-data-var finra-tip-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-finra-tip (tip-id uint))
  (map-get? finra-tips tip-id))

(define-read-only (get-certified-informant (informant-id principal))
  (map-get? certified-informants informant-id))

(define-read-only (get-enforcement-action (tip-id uint) (enforcer principal))
  (map-get? enforcement-actions {tip-id: tip-id, enforcer: enforcer}))

(define-public (submit-finra-tip (content-hash (buff 32)) (violation-type (string-ascii 50)) (firm-involved (string-ascii 100)) (monetary-harm uint))
  (let ((tip-id (+ (var-get finra-tip-count) u1))
        (informant-data (default-to {registration-number: "", verified: false, tips-submitted: u0} (map-get? certified-informants tx-sender))))
    (map-set finra-tips tip-id {hash: content-hash, violation-type: violation-type, firm-involved: firm-involved, monetary-harm: monetary-harm, timestamp: stacks-block-height, status: "submitted"})
    (map-set certified-informants tx-sender (merge informant-data {tips-submitted: (+ (get tips-submitted informant-data) u1)}))
    (var-set finra-tip-count tip-id)
    (ok tip-id)))

(define-public (certify-informant (informant principal) (registration-number (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (let ((informant-data (default-to {registration-number: "", verified: false, tips-submitted: u0} (map-get? certified-informants informant))))
      (ok (map-set certified-informants informant (merge informant-data {registration-number: registration-number, verified: true}))))))

(define-public (initiate-enforcement (tip-id uint) (action-type (string-ascii 50)) (fine-amount uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? finra-tips tip-id)) ERR_NOT_FOUND)
    (asserts! (> fine-amount u0) ERR_INVALID_PARAMS)
    (ok (map-set enforcement-actions {tip-id: tip-id, enforcer: tx-sender} {action-type: action-type, fine-amount: fine-amount, completed: false}))))

(define-public (complete-enforcement (tip-id uint))
  (let ((action (unwrap! (map-get? enforcement-actions {tip-id: tip-id, enforcer: tx-sender}) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (not (get completed action)) ERR_ALREADY_EXISTS)
    (ok (map-set enforcement-actions {tip-id: tip-id, enforcer: tx-sender} (merge action {completed: true})))))

(define-public (update-tip-status (tip-id uint) (new-status (string-ascii 20)))
  (let ((tip (unwrap! (map-get? finra-tips tip-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set finra-tips tip-id (merge tip {status: new-status})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
