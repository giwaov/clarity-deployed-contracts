(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-not-approved (err u105))
(define-constant err-data-inactive (err u106))

(define-data-var data-record-nonce uint u0)
(define-data-var request-nonce uint u0)

(define-map medical-data-records
  uint
  {
    healthcare-provider: principal,
    patient-id-hash: (buff 32),
    data-type: (string-ascii 40),
    data-hash: (buff 32),
    encryption-key-hash: (buff 32),
    consent-given: bool,
    active: bool,
    created-at: uint
  }
)

(define-map data-access-requests
  uint
  {
    requester: principal,
    record-id: uint,
    purpose: (string-ascii 60),
    approval-status: (string-ascii 20),
    approved-by: (optional principal),
    request-block: uint,
    expiry-block: uint,
    payment-amount: uint
  }
)

(define-map patient-consents
  {patient-hash: (buff 32), provider: principal}
  {
    consent-given: bool,
    consent-scope: (string-ascii 50),
    consent-date: uint,
    expiry-date: uint
  }
)

(define-map provider-records principal (list 200 uint))
(define-map record-access-list uint (list 50 uint))

(define-public (register-medical-data (patient-id-hash (buff 32)) (data-type (string-ascii 40)) (data-hash (buff 32)) (encryption-key-hash (buff 32)))
  (let
    (
      (record-id (+ (var-get data-record-nonce) u1))
    )
    (map-set medical-data-records record-id
      {
        healthcare-provider: tx-sender,
        patient-id-hash: patient-id-hash,
        data-type: data-type,
        data-hash: data-hash,
        encryption-key-hash: encryption-key-hash,
        consent-given: false,
        active: true,
        created-at: stacks-block-height
      }
    )
    (map-set provider-records tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? provider-records tx-sender)) record-id) u200)))
    (var-set data-record-nonce record-id)
    (ok record-id)
  )
)

(define-public (grant-patient-consent (record-id uint))
  (let
    (
      (record (unwrap! (map-get? medical-data-records record-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get healthcare-provider record)) err-unauthorized)
    (map-set medical-data-records record-id (merge record {consent-given: true}))
    (ok true)
  )
)

(define-public (request-data-access (record-id uint) (purpose (string-ascii 60)) (duration-blocks uint) (payment-amount uint))
  (let
    (
      (record (unwrap! (map-get? medical-data-records record-id) err-not-found))
      (request-id (+ (var-get request-nonce) u1))
    )
    (asserts! (get active record) err-data-inactive)
    (asserts! (> payment-amount u0) err-invalid-amount)
    (try! (stx-transfer? payment-amount tx-sender (as-contract tx-sender)))
    (map-set data-access-requests request-id
      {
        requester: tx-sender,
        record-id: record-id,
        purpose: purpose,
        approval-status: "pending",
        approved-by: none,
        request-block: stacks-block-height,
        expiry-block: (+ stacks-block-height duration-blocks),
        payment-amount: payment-amount
      }
    )
    (var-set request-nonce request-id)
    (ok request-id)
  )
)

(define-public (approve-data-access (request-id uint))
  (let
    (
      (request (unwrap! (map-get? data-access-requests request-id) err-not-found))
      (record (unwrap! (map-get? medical-data-records (get record-id request)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get healthcare-provider record)) err-unauthorized)
    (asserts! (get consent-given record) err-not-approved)
    (try! (as-contract (stx-transfer? (get payment-amount request) tx-sender (get healthcare-provider record))))
    (map-set data-access-requests request-id (merge request {
      approval-status: "approved",
      approved-by: (some tx-sender)
    }))
    (map-set record-access-list (get record-id request)
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? record-access-list (get record-id request))) request-id) u50)))
    (ok true)
  )
)

(define-public (reject-data-access (request-id uint))
  (let
    (
      (request (unwrap! (map-get? data-access-requests request-id) err-not-found))
      (record (unwrap! (map-get? medical-data-records (get record-id request)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get healthcare-provider record)) err-unauthorized)
    (try! (as-contract (stx-transfer? (get payment-amount request) tx-sender (get requester request))))
    (map-set data-access-requests request-id (merge request {
      approval-status: "rejected",
      approved-by: (some tx-sender)
    }))
    (ok true)
  )
)

(define-public (revoke-consent (record-id uint))
  (let
    (
      (record (unwrap! (map-get? medical-data-records record-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get healthcare-provider record)) err-unauthorized)
    (map-set medical-data-records record-id (merge record {consent-given: false}))
    (ok true)
  )
)

(define-public (deactivate-record (record-id uint))
  (let
    (
      (record (unwrap! (map-get? medical-data-records record-id) err-not-found))
    )
    (asserts! (is-eq tx-sender (get healthcare-provider record)) err-unauthorized)
    (map-set medical-data-records record-id (merge record {active: false}))
    (ok true)
  )
)

(define-read-only (get-medical-record (record-id uint))
  (ok (map-get? medical-data-records record-id))
)

(define-read-only (get-access-request (request-id uint))
  (ok (map-get? data-access-requests request-id))
)

(define-read-only (get-patient-consent (patient-hash (buff 32)) (provider principal))
  (ok (map-get? patient-consents {patient-hash: patient-hash, provider: provider}))
)

(define-read-only (get-provider-records (provider principal))
  (ok (map-get? provider-records provider))
)

(define-read-only (get-record-access-list (record-id uint))
  (ok (map-get? record-access-list record-id))
)
