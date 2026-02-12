(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map submissions uint {hash: (buff 32), timestamp: uint, encrypted: bool, status: (string-ascii 20), risk-level: uint})
(define-map journalists principal {verified: bool, pgp-key: (string-ascii 200), active: bool})
(define-map submission-access {submission-id: uint, journalist: principal} bool)
(define-data-var submission-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-submission (submission-id uint))
  (map-get? submissions submission-id))

(define-read-only (get-journalist (journalist-id principal))
  (map-get? journalists journalist-id))

(define-read-only (has-access (submission-id uint) (journalist principal))
  (default-to false (map-get? submission-access {submission-id: submission-id, journalist: journalist})))

(define-public (submit-leak (content-hash (buff 32)) (encrypted bool))
  (let ((submission-id (+ (var-get submission-count) u1)))
    (map-set submissions submission-id {hash: content-hash, timestamp: stacks-block-height, encrypted: encrypted, status: "pending", risk-level: u0})
    (var-set submission-count submission-id)
    (ok submission-id)))

(define-public (register-journalist (journalist principal) (pgp-key (string-ascii 200)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? journalists journalist)) ERR_ALREADY_EXISTS)
    (ok (map-set journalists journalist {verified: true, pgp-key: pgp-key, active: true}))))

(define-public (grant-access (submission-id uint) (journalist principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? submissions submission-id)) ERR_NOT_FOUND)
    (asserts! (is-some (map-get? journalists journalist)) ERR_NOT_FOUND)
    (ok (map-set submission-access {submission-id: submission-id, journalist: journalist} true))))

(define-public (update-submission-status (submission-id uint) (new-status (string-ascii 20)))
  (let ((submission (unwrap! (map-get? submissions submission-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set submissions submission-id (merge submission {status: new-status})))))

(define-public (set-risk-level (submission-id uint) (risk-level uint))
  (let ((submission (unwrap! (map-get? submissions submission-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (<= risk-level u10) ERR_INVALID_PARAMS)
    (ok (map-set submissions submission-id (merge submission {risk-level: risk-level})))))

(define-public (deactivate-journalist (journalist principal))
  (let ((journalist-data (unwrap! (map-get? journalists journalist) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set journalists journalist (merge journalist-data {active: false})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
