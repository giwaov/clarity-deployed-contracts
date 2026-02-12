(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-license-expired (err u102))
(define-constant err-already-registered (err u103))

(define-map aircraft-registry
  (string-ascii 32)
  {
    owner: principal,
    manufacturer: (string-ascii 64),
    model: (string-ascii 64),
    year: uint,
    registration-date: uint,
    license-expiry: uint,
    airworthiness-status: (string-ascii 32),
    active: bool
  })

(define-map maintenance-records
  {aircraft-id: (string-ascii 32), record-id: uint}
  {maintenance-date: uint, type: (string-ascii 64), certified-by: principal})

(define-data-var next-record-id uint u0)

(define-read-only (get-aircraft (aircraft-id (string-ascii 32)))
  (ok (map-get? aircraft-registry aircraft-id)))

(define-public (register-aircraft (aircraft-id (string-ascii 32)) (mfg (string-ascii 64)) (model (string-ascii 64)) (year uint) (expiry uint))
  (begin
    (asserts! (is-none (map-get? aircraft-registry aircraft-id)) err-already-registered)
    (ok (map-set aircraft-registry aircraft-id
      {owner: tx-sender, manufacturer: mfg, model: model, year: year,
       registration-date: stacks-block-height, license-expiry: expiry,
       airworthiness-status: "valid", active: true}))))

(define-public (renew-license (aircraft-id (string-ascii 32)) (new-expiry uint))
  (let ((aircraft (unwrap! (map-get? aircraft-registry aircraft-id) err-not-found)))
    (asserts! (is-eq tx-sender (get owner aircraft)) err-owner-only)
    (ok (map-set aircraft-registry aircraft-id (merge aircraft {license-expiry: new-expiry})))))

(define-public (update-airworthiness (aircraft-id (string-ascii 32)) (status (string-ascii 32)))
  (let ((aircraft (unwrap! (map-get? aircraft-registry aircraft-id) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set aircraft-registry aircraft-id (merge aircraft {airworthiness-status: status})))))

(define-public (add-maintenance-record (aircraft-id (string-ascii 32)) (type (string-ascii 64)))
  (let ((record-id (var-get next-record-id)))
    (asserts! (is-some (map-get? aircraft-registry aircraft-id)) err-not-found)
    (map-set maintenance-records {aircraft-id: aircraft-id, record-id: record-id}
      {maintenance-date: stacks-block-height, type: type, certified-by: tx-sender})
    (var-set next-record-id (+ record-id u1))
    (ok record-id)))
