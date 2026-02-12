(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-BUSINESS-NOT-FOUND (err u101))
(define-constant ERR-VERIFICATION-FAILED (err u102))

(define-map business-verifications
  { business-id: (string-ascii 50) }
  {
    business-name: (string-ascii 100),
    registration-number: (string-ascii 50),
    country: (string-ascii 30),
    business-type: (string-ascii 50),
    verified: bool,
    verification-date: uint,
    verifier: principal,
    documents-hash: (buff 32)
  }
)

(define-map verification-history
  { business-id: (string-ascii 50), record-id: uint }
  {
    action: (string-ascii 50),
    timestamp: uint,
    performer: principal,
    notes: (string-ascii 200)
  }
)

(define-data-var verifier-role principal tx-sender)

(define-public (submit-business-verification
  (business-id (string-ascii 50))
  (business-name (string-ascii 100))
  (reg-number (string-ascii 50))
  (country (string-ascii 30))
  (biz-type (string-ascii 50))
  (docs-hash (buff 32))
)
  (ok (map-set business-verifications
    { business-id: business-id }
    {
      business-name: business-name,
      registration-number: reg-number,
      country: country,
      business-type: biz-type,
      verified: false,
      verification-date: u0,
      verifier: tx-sender,
      documents-hash: docs-hash
    }
  ))
)

(define-public (approve-verification (business-id (string-ascii 50)) (record-id uint))
  (let ((business (unwrap! (map-get? business-verifications { business-id: business-id }) ERR-BUSINESS-NOT-FOUND)))
    (asserts! (is-eq tx-sender (var-get verifier-role)) ERR-NOT-AUTHORIZED)
    (map-set business-verifications
      { business-id: business-id }
      (merge business { verified: true, verification-date: stacks-block-height })
    )
    (ok (map-set verification-history
      { business-id: business-id, record-id: record-id }
      {
        action: "approved",
        timestamp: stacks-block-height,
        performer: tx-sender,
        notes: ""
      }
    ))
  )
)

(define-public (revoke-verification (business-id (string-ascii 50)) (record-id uint) (reason (string-ascii 200)))
  (let ((business (unwrap! (map-get? business-verifications { business-id: business-id }) ERR-BUSINESS-NOT-FOUND)))
    (asserts! (is-eq tx-sender (var-get verifier-role)) ERR-NOT-AUTHORIZED)
    (map-set business-verifications
      { business-id: business-id }
      (merge business { verified: false })
    )
    (ok (map-set verification-history
      { business-id: business-id, record-id: record-id }
      {
        action: "revoked",
        timestamp: stacks-block-height,
        performer: tx-sender,
        notes: reason
      }
    ))
  )
)

(define-read-only (get-business-info (business-id (string-ascii 50)))
  (map-get? business-verifications { business-id: business-id })
)

(define-read-only (get-verification-record (business-id (string-ascii 50)) (record-id uint))
  (map-get? verification-history { business-id: business-id, record-id: record-id })
)

(define-public (update-verifier-role (new-verifier principal))
  (begin
    (asserts! (is-eq tx-sender (var-get verifier-role)) ERR-NOT-AUTHORIZED)
    (ok (var-set verifier-role new-verifier))
  )
)

(define-public (update-documents-hash (business-id (string-ascii 50)) (new-hash (buff 32)))
  (let ((business (unwrap! (map-get? business-verifications { business-id: business-id }) ERR-BUSINESS-NOT-FOUND)))
    (ok (map-set business-verifications
      { business-id: business-id }
      (merge business { documents-hash: new-hash })
    ))
  )
)
