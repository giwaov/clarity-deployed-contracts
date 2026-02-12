(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-ADDRESS-NOT-FOUND (err u101))
(define-constant ERR-VERIFICATION-FAILED (err u102))

(define-map address-verifications
  { address-id: (string-ascii 100) }
  {
    wallet-address: principal,
    street-address: (string-ascii 200),
    city: (string-ascii 50),
    country: (string-ascii 30),
    postal-code: (string-ascii 20),
    verified: bool,
    verification-date: uint,
    verifier: principal,
    proof-hash: (buff 32)
  }
)

(define-map verification-attempts
  { address-id: (string-ascii 100), attempt-id: uint }
  {
    attempt-date: uint,
    method: (string-ascii 50),
    result: (string-ascii 20),
    notes: (string-ascii 200)
  }
)

(define-data-var verifier-role principal tx-sender)

(define-public (submit-address-verification
  (address-id (string-ascii 100))
  (wallet principal)
  (street (string-ascii 200))
  (city (string-ascii 50))
  (country (string-ascii 30))
  (postal (string-ascii 20))
  (proof-hash (buff 32))
)
  (ok (map-set address-verifications
    { address-id: address-id }
    {
      wallet-address: wallet,
      street-address: street,
      city: city,
      country: country,
      postal-code: postal,
      verified: false,
      verification-date: u0,
      verifier: tx-sender,
      proof-hash: proof-hash
    }
  ))
)

(define-public (approve-address-verification (address-id (string-ascii 100)) (attempt-id uint))
  (let ((address (unwrap! (map-get? address-verifications { address-id: address-id }) ERR-ADDRESS-NOT-FOUND)))
    (asserts! (is-eq tx-sender (var-get verifier-role)) ERR-NOT-AUTHORIZED)
    (map-set address-verifications
      { address-id: address-id }
      (merge address { verified: true, verification-date: stacks-block-height })
    )
    (ok (map-set verification-attempts
      { address-id: address-id, attempt-id: attempt-id }
      {
        attempt-date: stacks-block-height,
        method: "document-review",
        result: "approved",
        notes: ""
      }
    ))
  )
)

(define-public (reject-address-verification (address-id (string-ascii 100)) (attempt-id uint) (reason (string-ascii 200)))
  (let ((address (unwrap! (map-get? address-verifications { address-id: address-id }) ERR-ADDRESS-NOT-FOUND)))
    (asserts! (is-eq tx-sender (var-get verifier-role)) ERR-NOT-AUTHORIZED)
    (ok (map-set verification-attempts
      { address-id: address-id, attempt-id: attempt-id }
      {
        attempt-date: stacks-block-height,
        method: "document-review",
        result: "rejected",
        notes: reason
      }
    ))
  )
)

(define-public (revoke-verification (address-id (string-ascii 100)))
  (let ((address (unwrap! (map-get? address-verifications { address-id: address-id }) ERR-ADDRESS-NOT-FOUND)))
    (asserts! (is-eq tx-sender (var-get verifier-role)) ERR-NOT-AUTHORIZED)
    (ok (map-set address-verifications
      { address-id: address-id }
      (merge address { verified: false })
    ))
  )
)

(define-read-only (get-address-info (address-id (string-ascii 100)))
  (map-get? address-verifications { address-id: address-id })
)

(define-read-only (get-attempt-info (address-id (string-ascii 100)) (attempt-id uint))
  (map-get? verification-attempts { address-id: address-id, attempt-id: attempt-id })
)

(define-public (update-proof-hash (address-id (string-ascii 100)) (new-hash (buff 32)))
  (let ((address (unwrap! (map-get? address-verifications { address-id: address-id }) ERR-ADDRESS-NOT-FOUND)))
    (ok (map-set address-verifications
      { address-id: address-id }
      (merge address { proof-hash: new-hash })
    ))
  )
)
