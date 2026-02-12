(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map safety-complaints uint {hash: (buff 32), hazard-type: (string-ascii 50), industry: (string-ascii 30), severity: uint, timestamp: uint, retaliation-claimed: bool, status: (string-ascii 20)})
(define-map protected-employees principal {employee-id: (string-ascii 50), protection-status: bool, complaint-count: uint})
(define-map investigation-records {complaint-id: uint, investigator: principal} {findings: (buff 32), sanctions-recommended: bool})
(define-data-var safety-complaint-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-safety-complaint (complaint-id uint))
  (map-get? safety-complaints complaint-id))

(define-read-only (get-protected-employee (employee-id principal))
  (map-get? protected-employees employee-id))

(define-read-only (get-investigation-record (complaint-id uint) (investigator principal))
  (map-get? investigation-records {complaint-id: complaint-id, investigator: investigator}))

(define-public (file-safety-complaint (content-hash (buff 32)) (hazard-type (string-ascii 50)) (industry (string-ascii 30)) (severity uint))
  (let ((complaint-id (+ (var-get safety-complaint-count) u1))
        (employee-data (default-to {employee-id: "", protection-status: false, complaint-count: u0} (map-get? protected-employees tx-sender))))
    (asserts! (<= severity u5) ERR_INVALID_PARAMS)
    (map-set safety-complaints complaint-id {hash: content-hash, hazard-type: hazard-type, industry: industry, severity: severity, timestamp: stacks-block-height, retaliation-claimed: false, status: "filed"})
    (map-set protected-employees tx-sender (merge employee-data {protection-status: true, complaint-count: (+ (get complaint-count employee-data) u1)}))
    (var-set safety-complaint-count complaint-id)
    (ok complaint-id)))

(define-public (claim-retaliation (complaint-id uint))
  (let ((complaint (unwrap! (map-get? safety-complaints complaint-id) ERR_NOT_FOUND)))
    (asserts! (is-some (map-get? protected-employees tx-sender)) ERR_UNAUTHORIZED)
    (ok (map-set safety-complaints complaint-id (merge complaint {retaliation-claimed: true})))))

(define-public (record-investigation (complaint-id uint) (findings (buff 32)) (sanctions-recommended bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-some (map-get? safety-complaints complaint-id)) ERR_NOT_FOUND)
    (ok (map-set investigation-records {complaint-id: complaint-id, investigator: tx-sender} {findings: findings, sanctions-recommended: sanctions-recommended}))))

(define-public (update-complaint-status (complaint-id uint) (new-status (string-ascii 20)))
  (let ((complaint (unwrap! (map-get? safety-complaints complaint-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set safety-complaints complaint-id (merge complaint {status: new-status})))))

(define-public (revoke-protection (employee principal))
  (let ((employee-data (unwrap! (map-get? protected-employees employee) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set protected-employees employee (merge employee-data {protection-status: false})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
