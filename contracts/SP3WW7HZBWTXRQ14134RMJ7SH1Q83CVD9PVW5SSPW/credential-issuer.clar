;; Credential Issuer Contract

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))

(define-data-var next-credential-id uint u1)

(define-map credentials
  uint
  {
    holder: principal,
    credential-type: (string-ascii 64),
    issued-at: uint,
    revoked: bool
  }
)

(define-read-only (get-credential (credential-id uint))
  (map-get? credentials credential-id)
)

(define-public (issue-credential (holder principal) (credential-type (string-ascii 64)))
  (let ((credential-id (var-get next-credential-id)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set credentials credential-id {
      holder: holder,
      credential-type: credential-type,
      issued-at: block-height,
      revoked: false
    })
    (var-set next-credential-id (+ credential-id u1))
    (ok credential-id)
  )
)

(define-public (revoke-credential (credential-id uint))
  (let ((credential (unwrap! (map-get? credentials credential-id) (err u101))))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set credentials credential-id (merge credential { revoked: true }))
    (ok true)
  )
)
