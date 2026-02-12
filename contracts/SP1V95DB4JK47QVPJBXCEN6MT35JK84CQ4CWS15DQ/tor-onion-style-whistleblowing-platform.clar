(define-constant ERR_UNAUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_EXISTS (err u102))
(define-constant ERR_INVALID_PARAMS (err u103))

(define-data-var contract-owner principal tx-sender)

(define-map hidden-services uint {onion-address: (string-ascii 100), content-hash: (buff 32), layer-count: uint, timestamp: uint, accessible: bool})
(define-map tor-nodes principal {node-type: (string-ascii 20), bandwidth: uint, uptime: uint, trusted: bool})
(define-map anonymous-submissions {service-id: uint, submitter-hash: (buff 32)} {submission-hash: (buff 32), routed-through: uint, verified: bool})
(define-data-var service-count uint u0)

(define-read-only (get-owner) (var-get contract-owner))

(define-read-only (get-hidden-service (service-id uint))
  (map-get? hidden-services service-id))

(define-read-only (get-tor-node (node-id principal))
  (map-get? tor-nodes node-id))

(define-read-only (get-anonymous-submission (service-id uint) (submitter-hash (buff 32)))
  (map-get? anonymous-submissions {service-id: service-id, submitter-hash: submitter-hash}))

(define-public (create-hidden-service (onion-address (string-ascii 100)) (content-hash (buff 32)) (layer-count uint))
  (let ((service-id (+ (var-get service-count) u1)))
    (asserts! (and (> layer-count u0) (<= layer-count u10)) ERR_INVALID_PARAMS)
    (map-set hidden-services service-id {onion-address: onion-address, content-hash: content-hash, layer-count: layer-count, timestamp: stacks-block-height, accessible: true})
    (var-set service-count service-id)
    (ok service-id)))

(define-public (register-tor-node (node-type (string-ascii 20)) (bandwidth uint))
  (begin
    (asserts! (is-none (map-get? tor-nodes tx-sender)) ERR_ALREADY_EXISTS)
    (asserts! (> bandwidth u0) ERR_INVALID_PARAMS)
    (ok (map-set tor-nodes tx-sender {node-type: node-type, bandwidth: bandwidth, uptime: u0, trusted: false}))))

(define-public (trust-node (node principal))
  (let ((node-data (unwrap! (map-get? tor-nodes node) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set tor-nodes node (merge node-data {trusted: true})))))

(define-public (submit-anonymously (service-id uint) (submitter-hash (buff 32)) (submission-hash (buff 32)) (routed-through uint))
  (begin
    (asserts! (is-some (map-get? hidden-services service-id)) ERR_NOT_FOUND)
    (asserts! (> routed-through u2) ERR_INVALID_PARAMS)
    (ok (map-set anonymous-submissions {service-id: service-id, submitter-hash: submitter-hash} {submission-hash: submission-hash, routed-through: routed-through, verified: false}))))

(define-public (verify-submission (service-id uint) (submitter-hash (buff 32)))
  (let ((submission (unwrap! (map-get? anonymous-submissions {service-id: service-id, submitter-hash: submitter-hash}) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set anonymous-submissions {service-id: service-id, submitter-hash: submitter-hash} (merge submission {verified: true})))))

(define-public (disable-service (service-id uint))
  (let ((service (unwrap! (map-get? hidden-services service-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (map-set hidden-services service-id (merge service {accessible: false})))))

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_UNAUTHORIZED)
    (ok (var-set contract-owner new-owner))))
