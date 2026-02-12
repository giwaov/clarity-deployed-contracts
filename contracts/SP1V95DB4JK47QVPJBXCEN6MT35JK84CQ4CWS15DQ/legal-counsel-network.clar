(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-case-closed (err u105))

(define-data-var counsel-nonce uint u0)
(define-data-var case-nonce uint u0)

(define-map legal-counsels
  uint
  {
    lawyer: principal,
    specialization: (string-ascii 40),
    credentials-hash: (buff 32),
    hourly-rate: uint,
    verified: bool,
    total-cases: uint,
    rating-sum: uint,
    rating-count: uint
  }
)

(define-map legal-cases
  uint
  {
    client: principal,
    counsel-id: uint,
    case-description-hash: (buff 32),
    escrow-amount: uint,
    hours-estimated: uint,
    hours-billed: uint,
    status: (string-ascii 20),
    opened-at: uint,
    closed-at: (optional uint)
  }
)

(define-map case-documents
  {case-id: uint, document-id: uint}
  {
    document-hash: (buff 32),
    uploaded-by: principal,
    timestamp: uint,
    document-type: (string-ascii 30)
  }
)

(define-map lawyer-counsels principal (list 20 uint))
(define-map counsel-cases uint (list 100 uint))
(define-map document-count uint uint)

(define-public (register-counsel (specialization (string-ascii 40)) (credentials-hash (buff 32)) (hourly-rate uint))
  (let
    (
      (counsel-id (+ (var-get counsel-nonce) u1))
    )
    (asserts! (> hourly-rate u0) err-invalid-amount)
    (map-set legal-counsels counsel-id
      {
        lawyer: tx-sender,
        specialization: specialization,
        credentials-hash: credentials-hash,
        hourly-rate: hourly-rate,
        verified: false,
        total-cases: u0,
        rating-sum: u0,
        rating-count: u0
      }
    )
    (map-set lawyer-counsels tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? lawyer-counsels tx-sender)) counsel-id) u20)))
    (var-set counsel-nonce counsel-id)
    (ok counsel-id)
  )
)

(define-public (open-case (counsel-id uint) (case-description-hash (buff 32)) (hours-estimated uint))
  (let
    (
      (counsel (unwrap! (map-get? legal-counsels counsel-id) err-not-found))
      (case-id (+ (var-get case-nonce) u1))
      (escrow-amount (* hours-estimated (get hourly-rate counsel)))
    )
    (asserts! (get verified counsel) err-not-found)
    (asserts! (> hours-estimated u0) err-invalid-amount)
    (try! (stx-transfer? escrow-amount tx-sender (as-contract tx-sender)))
    (map-set legal-cases case-id
      {
        client: tx-sender,
        counsel-id: counsel-id,
        case-description-hash: case-description-hash,
        escrow-amount: escrow-amount,
        hours-estimated: hours-estimated,
        hours-billed: u0,
        status: "open",
        opened-at: stacks-block-height,
        closed-at: none
      }
    )
    (map-set document-count case-id u0)
    (map-set counsel-cases counsel-id
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? counsel-cases counsel-id)) case-id) u100)))
    (var-set case-nonce case-id)
    (ok case-id)
  )
)

(define-public (upload-document (case-id uint) (document-hash (buff 32)) (document-type (string-ascii 30)))
  (let
    (
      (case (unwrap! (map-get? legal-cases case-id) err-not-found))
      (counsel (unwrap! (map-get? legal-counsels (get counsel-id case)) err-not-found))
      (doc-id (+ (default-to u0 (map-get? document-count case-id)) u1))
    )
    (asserts! (or (is-eq tx-sender (get client case)) (is-eq tx-sender (get lawyer counsel))) err-unauthorized)
    (map-set case-documents {case-id: case-id, document-id: doc-id}
      {
        document-hash: document-hash,
        uploaded-by: tx-sender,
        timestamp: stacks-block-height,
        document-type: document-type
      }
    )
    (map-set document-count case-id doc-id)
    (ok doc-id)
  )
)

(define-public (bill-hours (case-id uint) (hours uint))
  (let
    (
      (case (unwrap! (map-get? legal-cases case-id) err-not-found))
      (counsel (unwrap! (map-get? legal-counsels (get counsel-id case)) err-not-found))
      (billing-amount (* hours (get hourly-rate counsel)))
    )
    (asserts! (is-eq tx-sender (get lawyer counsel)) err-unauthorized)
    (asserts! (not (is-eq (get status case) "closed")) err-case-closed)
    (asserts! (<= billing-amount (get escrow-amount case)) err-invalid-amount)
    (try! (as-contract (stx-transfer? billing-amount tx-sender (get lawyer counsel))))
    (map-set legal-cases case-id (merge case {
      hours-billed: (+ (get hours-billed case) hours),
      escrow-amount: (- (get escrow-amount case) billing-amount)
    }))
    (ok true)
  )
)

(define-public (close-case (case-id uint) (rating uint))
  (let
    (
      (case (unwrap! (map-get? legal-cases case-id) err-not-found))
      (counsel (unwrap! (map-get? legal-counsels (get counsel-id case)) err-not-found))
    )
    (asserts! (is-eq tx-sender (get client case)) err-unauthorized)
    (asserts! (not (is-eq (get status case) "closed")) err-already-exists)
    (asserts! (<= rating u100) err-invalid-amount)
    (if (> (get escrow-amount case) u0)
      (try! (as-contract (stx-transfer? (get escrow-amount case) tx-sender (get client case))))
      true
    )
    (map-set legal-cases case-id (merge case {
      status: "closed",
      closed-at: (some stacks-block-height),
      escrow-amount: u0
    }))
    (map-set legal-counsels (get counsel-id case) (merge counsel {
      total-cases: (+ (get total-cases counsel) u1),
      rating-sum: (+ (get rating-sum counsel) rating),
      rating-count: (+ (get rating-count counsel) u1)
    }))
    (ok true)
  )
)

(define-public (verify-counsel (counsel-id uint))
  (let
    (
      (counsel (unwrap! (map-get? legal-counsels counsel-id) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set legal-counsels counsel-id (merge counsel {verified: true}))
    (ok true)
  )
)

(define-read-only (get-counsel (counsel-id uint))
  (ok (map-get? legal-counsels counsel-id))
)

(define-read-only (get-case (case-id uint))
  (ok (map-get? legal-cases case-id))
)

(define-read-only (get-document (case-id uint) (document-id uint))
  (ok (map-get? case-documents {case-id: case-id, document-id: document-id}))
)

(define-read-only (get-lawyer-counsels (lawyer principal))
  (ok (map-get? lawyer-counsels lawyer))
)

(define-read-only (get-counsel-cases (counsel-id uint))
  (ok (map-get? counsel-cases counsel-id))
)

(define-read-only (get-average-rating (counsel-id uint))
  (let
    (
      (counsel (unwrap! (map-get? legal-counsels counsel-id) err-not-found))
      (count (get rating-count counsel))
    )
    (ok (if (> count u0) (/ (get rating-sum counsel) count) u0))
  )
)
