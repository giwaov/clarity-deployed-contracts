(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1900))
(define-constant ERR_ATTESTATION_NOT_FOUND (err u1901))
(define-constant ERR_INVALID_SIGNATURE (err u1902))

(define-data-var next-attestation-id uint u1)

(define-map attestations
  uint
  {
    issuer: principal,
    subject: principal,
    attestation-type: (string-ascii 64),
    data-hash: (buff 32),
    signature: (buff 64),
    public-key: (buff 33),
    timestamp: uint,
    revoked: bool
  }
)

(define-map subject-attestations
  principal
  (list 100 uint)
)

(define-map issuer-attestations
  principal
  (list 100 uint)
)

(define-read-only (get-contract-hash)
  (contract-hash? .attestation-management)
)

(define-read-only (get-attestation (attestation-id uint))
  (ok (unwrap! (map-get? attestations attestation-id) ERR_ATTESTATION_NOT_FOUND))
)

(define-read-only (get-subject-attestations (subject principal))
  (ok (default-to (list) (map-get? subject-attestations subject)))
)

(define-read-only (get-issuer-attestations (issuer principal))
  (ok (default-to (list) (map-get? issuer-attestations issuer)))
)

(define-public (create-attestation 
  (subject principal)
  (attestation-type (string-ascii 64))
  (data-hash (buff 32))
  (signature (buff 64))
  (public-key (buff 33))
)
  (let
    (
      (attestation-id (var-get next-attestation-id))
    )
    (asserts! (secp256r1-verify data-hash signature public-key) ERR_INVALID_SIGNATURE)
    (map-set attestations attestation-id {
      issuer: tx-sender,
      subject: subject,
      attestation-type: attestation-type,
      data-hash: data-hash,
      signature: signature,
      public-key: public-key,
      timestamp: stacks-block-time,
      revoked: false
    })
    (let
      (
        (subject-list (default-to (list) (map-get? subject-attestations subject)))
        (issuer-list (default-to (list) (map-get? issuer-attestations tx-sender)))
      )
      (map-set subject-attestations subject (unwrap-panic (as-max-len? (append subject-list attestation-id) u100)))
      (map-set issuer-attestations tx-sender (unwrap-panic (as-max-len? (append issuer-list attestation-id) u100)))
    )
    (var-set next-attestation-id (+ attestation-id u1))
    (ok attestation-id)
  )
)

(define-public (revoke-attestation (attestation-id uint))
  (let
    (
      (attestation-data (unwrap! (map-get? attestations attestation-id) ERR_ATTESTATION_NOT_FOUND))
    )
    (asserts! (is-eq (get issuer attestation-data) tx-sender) ERR_NOT_AUTHORIZED)
    (map-set attestations attestation-id (merge attestation-data {revoked: true}))
    (ok true)
  )
)

(define-public (verify-attestation (attestation-id uint))
  (let
    (
      (attestation-data (unwrap! (map-get? attestations attestation-id) ERR_ATTESTATION_NOT_FOUND))
    )
    (ok (and 
      (not (get revoked attestation-data))
      (secp256r1-verify 
        (get data-hash attestation-data)
        (get signature attestation-data)
        (get public-key attestation-data)
      )
    ))
  )
)

(define-read-only (check-attestation-validity (attestation-id uint))
  (let
    (
      (attestation-data (unwrap! (map-get? attestations attestation-id) ERR_ATTESTATION_NOT_FOUND))
    )
    (ok (not (get revoked attestation-data)))
  )
)

(define-read-only (verify-sig (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (ok (secp256r1-verify message signature public-key))
)

(define-read-only (get-time)
  stacks-block-time
)

(define-read-only (check-asset-restrict)
  (ok (is-ok (contract-hash? .attestation-management)))
)
