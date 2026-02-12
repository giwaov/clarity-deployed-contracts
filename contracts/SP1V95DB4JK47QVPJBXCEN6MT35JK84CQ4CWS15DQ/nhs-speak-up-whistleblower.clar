(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map concerns uint {hash: (buff 32), concern-type: (string-ascii 50), department: (string-ascii 100), severity: uint, timestamp: uint, anonymous: bool, status: (string-ascii 20)})
(define-map speak-up-guardians principal {trust-name: (string-ascii 100), region: (string-ascii 50), active: bool})
(define-map guardian-responses {concern-id: uint, guardian: principal} {response-hash: (buff 32), action-plan: (string-ascii 200), resolved: bool})
(define-data-var concern-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-concern (concern-id uint))
  (map-get? concerns concern-id))

(define-read-only (get-speak-up-guardian (guardian-id principal))
  (map-get? speak-up-guardians guardian-id))

(define-read-only (get-guardian-response (concern-id uint) (guardian principal))
  (map-get? guardian-responses {concern-id: concern-id, guardian: guardian}))

(define-public (raise-concern (content-hash (buff 32)) (concern-type (string-ascii 50)) (department (string-ascii 100)) (severity uint) (anonymous bool))
  (let ((concern-id (+ (var-get concern-count) u1)))
    (asserts! (<= severity u5) ERR_INVALID_PARAMS)
    (map-set concerns concern-id {hash: content-hash, concern-type: concern-type, department: department, severity: severity, timestamp: stacks-block-height, anonymous: anonymous, status: "raised"})
    (var-set concern-count concern-id)
    (ok concern-id)))

(define-public (appoint-guardian (guardian principal) (trust-name (string-ascii 100)) (region (string-ascii 50)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? speak-up-guardians guardian)) ERR_ALREADY_EXISTS)
    (ok (map-set speak-up-guardians guardian {trust-name: trust-name, region: region, active: true}))))

(define-public (respond-to-concern (concern-id uint) (response-hash (buff 32)) (action-plan (string-ascii 200)))
  (let ((guardian-data (unwrap! (map-get? speak-up-guardians tx-sender) ERR_UNAUTHORIZED)))
    (asserts! (is-some (map-get? concerns concern-id)) ERR_NOT_FOUND)
    (asserts! (get active guardian-data) ERR_UNAUTHORIZED)
    (ok (map-set guardian-responses {concern-id: concern-id, guardian: tx-sender} {response-hash: response-hash, action-plan: action-plan, resolved: false}))))

(define-public (resolve-concern (concern-id uint))
  (let ((response (unwrap! (map-get? guardian-responses {concern-id: concern-id, guardian: tx-sender}) ERR_NOT_FOUND)))
    (asserts! (is-some (map-get? speak-up-guardians tx-sender)) ERR_UNAUTHORIZED)
    (asserts! (not (get resolved response)) ERR_ALREADY_EXISTS)
    (ok (map-set guardian-responses {concern-id: concern-id, guardian: tx-sender} (merge response {resolved: true})))))

(define-public (update-concern-status (concern-id uint) (new-status (string-ascii 20)))
  (let ((concern (unwrap! (map-get? concerns concern-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set concerns concern-id (merge concern {status: new-status})))))

(define-public (deactivate-guardian (guardian principal))
  (let ((guardian-data (unwrap! (map-get? speak-up-guardians guardian) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set speak-up-guardians guardian (merge guardian-data {active: false})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
