(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map esim-profiles uint {iccid: (string-ascii 50), carrier: (string-ascii 50), plan-type: (string-ascii 30), data-allowance: uint, activated: bool, activation-date: uint})
(define-map device-registry principal {device-id: (string-ascii 50), manufacturer: (string-ascii 50), model: (string-ascii 50), esim-capable: bool})
(define-map activation-requests uint {device: principal, profile-id: uint, requested-at: uint, approved: bool, completed: bool})
(define-map carrier-partners (string-ascii 50) {partner-name: (string-ascii 100), supported-regions: uint, active: bool})
(define-data-var profile-count uint u0)
(define-data-var request-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-esim-profile (profile-id uint))
  (map-get? esim-profiles profile-id))

(define-read-only (get-device (device-id principal))
  (map-get? device-registry device-id))

(define-read-only (get-activation-request (request-id uint))
  (map-get? activation-requests request-id))

(define-read-only (get-carrier-partner (carrier-id (string-ascii 50)))
  (map-get? carrier-partners carrier-id))

(define-public (create-esim-profile (iccid (string-ascii 50)) (carrier (string-ascii 50)) (plan-type (string-ascii 30)) (data-allowance uint))
  (let ((profile-id (+ (var-get profile-count) u1)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (> data-allowance u0) ERR_INVALID_PARAMS)
    (map-set esim-profiles profile-id {iccid: iccid, carrier: carrier, plan-type: plan-type, data-allowance: data-allowance, activated: false, activation-date: u0})
    (var-set profile-count profile-id)
    (ok profile-id)))

(define-public (register-device (device-id (string-ascii 50)) (manufacturer (string-ascii 50)) (model (string-ascii 50)) (esim-capable bool))
  (begin
    (asserts! (is-none (map-get? device-registry tx-sender)) ERR_ALREADY_EXISTS)
    (ok (map-set device-registry tx-sender {device-id: device-id, manufacturer: manufacturer, model: model, esim-capable: esim-capable}))))

(define-public (request-activation (profile-id uint))
  (let ((request-id (+ (var-get request-count) u1))
        (device (unwrap! (map-get? device-registry tx-sender) ERR_UNAUTHORIZED))
        (profile (unwrap! (map-get? esim-profiles profile-id) ERR_NOT_FOUND)))
    (asserts! (get esim-capable device) ERR_UNAUTHORIZED)
    (asserts! (not (get activated profile)) ERR_ALREADY_EXISTS)
    (map-set activation-requests request-id {device: tx-sender, profile-id: profile-id, requested-at: stacks-block-height, approved: false, completed: false})
    (var-set request-count request-id)
    (ok request-id)))

(define-public (approve-activation (request-id uint))
  (let ((request (unwrap! (map-get? activation-requests request-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (not (get approved request)) ERR_ALREADY_EXISTS)
    (ok (map-set activation-requests request-id (merge request {approved: true})))))

(define-public (complete-activation (request-id uint))
  (let ((request (unwrap! (map-get? activation-requests request-id) ERR_NOT_FOUND))
        (profile (unwrap! (map-get? esim-profiles (get profile-id request)) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (get approved request) ERR_UNAUTHORIZED)
    (asserts! (not (get completed request)) ERR_ALREADY_EXISTS)
    (map-set activation-requests request-id (merge request {completed: true}))
    (ok (map-set esim-profiles (get profile-id request) (merge profile {activated: true, activation-date: stacks-block-height})))))

(define-public (add-carrier-partner (carrier-id (string-ascii 50)) (partner-name (string-ascii 100)) (supported-regions uint))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? carrier-partners carrier-id)) ERR_ALREADY_EXISTS)
    (asserts! (> supported-regions u0) ERR_INVALID_PARAMS)
    (ok (map-set carrier-partners carrier-id {partner-name: partner-name, supported-regions: supported-regions, active: true}))))

(define-public (deactivate-carrier (carrier-id (string-ascii 50)))
  (let ((carrier (unwrap! (map-get? carrier-partners carrier-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set carrier-partners carrier-id (merge carrier {active: false})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
