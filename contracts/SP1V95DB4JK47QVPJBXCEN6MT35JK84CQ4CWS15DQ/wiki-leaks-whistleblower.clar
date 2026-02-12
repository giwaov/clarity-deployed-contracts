(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map leaks uint {hash: (buff 32), source-type: (string-ascii 30), classification: (string-ascii 30), published: bool, timestamp: uint, impact-score: uint})
(define-map publishers principal {verified: bool, reputation: uint, active: bool})
(define-map publication-metadata {leak-id: uint, publisher: principal} {published-at: uint, redacted: bool})
(define-data-var leak-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-leak (leak-id uint))
  (map-get? leaks leak-id))

(define-read-only (get-publisher (publisher-id principal))
  (map-get? publishers publisher-id))

(define-read-only (get-publication (leak-id uint) (publisher principal))
  (map-get? publication-metadata {leak-id: leak-id, publisher: publisher}))

(define-public (submit-leak (content-hash (buff 32)) (source-type (string-ascii 30)) (classification (string-ascii 30)))
  (let ((leak-id (+ (var-get leak-count) u1)))
    (map-set leaks leak-id {hash: content-hash, source-type: source-type, classification: classification, published: false, timestamp: stacks-block-height, impact-score: u0})
    (var-set leak-count leak-id)
    (ok leak-id)))

(define-public (register-publisher (publisher principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (is-none (map-get? publishers publisher)) ERR_ALREADY_EXISTS)
    (ok (map-set publishers publisher {verified: true, reputation: u50, active: true}))))

(define-public (publish-leak (leak-id uint) (redacted bool))
  (let ((leak (unwrap! (map-get? leaks leak-id) ERR_NOT_FOUND))
        (publisher-data (unwrap! (map-get? publishers tx-sender) ERR_UNAUTHORIZED)))
    (asserts! (get active publisher-data) ERR_UNAUTHORIZED)
    (asserts! (not (get published leak)) ERR_ALREADY_EXISTS)
    (map-set leaks leak-id (merge leak {published: true}))
    (ok (map-set publication-metadata {leak-id: leak-id, publisher: tx-sender} {published-at: stacks-block-height, redacted: redacted}))))

(define-public (update-impact-score (leak-id uint) (score uint))
  (let ((leak (unwrap! (map-get? leaks leak-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (<= score u100) ERR_INVALID_PARAMS)
    (ok (map-set leaks leak-id (merge leak {impact-score: score})))))

(define-public (update-publisher-reputation (publisher principal) (new-reputation uint))
  (let ((publisher-data (unwrap! (map-get? publishers publisher) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (asserts! (<= new-reputation u100) ERR_INVALID_PARAMS)
    (ok (map-set publishers publisher (merge publisher-data {reputation: new-reputation})))))

(define-public (deactivate-publisher (publisher principal))
  (let ((publisher-data (unwrap! (map-get? publishers publisher) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set publishers publisher (merge publisher-data {active: false})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
