;; Verifier Contract

(define-constant err-not-found (err u100))
(define-constant err-revoked (err u101))

(define-read-only (verify-credential (credential-id uint))
  (match (contract-call? .credential-issuer get-credential credential-id)
    credential (ok (not (get revoked credential)))
    (err err-not-found)
  )
)

(define-read-only (check-validity (credential-id uint))
  (match (contract-call? .credential-issuer get-credential credential-id)
    credential (if (get revoked credential)
                 (err err-revoked)
                 (ok true))
    (err err-not-found)
  )
)
