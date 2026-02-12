(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u600))
(define-constant ERR_INVALID_SIGNATURE (err u601))
(define-constant ERR_AUDIT_NOT_FOUND (err u602))

(define-data-var next-audit-id uint u1)

(define-map audit-summaries
  uint
  {
    auditor: principal,
    contract-address: principal,
    audit-hash: (buff 32),
    finding-count: uint,
    risk-score: uint,
    timestamp: uint,
    signature-type: (string-ascii 20),
    signature: (buff 64),
    public-key: (buff 33)
  }
)

(define-map audit-findings
  {audit-id: uint, finding-index: uint}
  {
    severity: (string-ascii 20),
    description: (string-ascii 512),
    location: (string-ascii 256)
  }
)

(define-read-only (get-contract-hash)
  (contract-hash? .audit-report)
)

(define-read-only (get-audit-summary (audit-id uint))
  (ok (unwrap! (map-get? audit-summaries audit-id) ERR_AUDIT_NOT_FOUND))
)

(define-read-only (get-finding (audit-id uint) (finding-index uint))
  (ok (unwrap! (map-get? audit-findings {audit-id: audit-id, finding-index: finding-index}) ERR_AUDIT_NOT_FOUND))
)

(define-public (submit-audit 
  (auditor principal)
  (contract-address principal)
  (audit-hash (buff 32))
  (finding-count uint)
  (risk-score uint)
  (signature-type (string-ascii 20))
  (signature (buff 64))
  (public-key (buff 33))
)
  (let
    (
      (audit-id (var-get next-audit-id))
    )
    (asserts! (is-eq tx-sender auditor) ERR_NOT_AUTHORIZED)
    (if (is-eq signature-type "SECP256R1")
      (asserts! (secp256r1-verify audit-hash signature public-key) ERR_INVALID_SIGNATURE)
      true
    )
    (map-set audit-summaries audit-id {
      auditor: auditor,
      contract-address: contract-address,
      audit-hash: audit-hash,
      finding-count: finding-count,
      risk-score: risk-score,
      timestamp: stacks-block-time,
      signature-type: signature-type,
      signature: signature,
      public-key: public-key
    })
    (var-set next-audit-id (+ audit-id u1))
    (ok audit-id)
  )
)

(define-public (add-finding 
  (audit-id uint)
  (finding-index uint)
  (severity (string-ascii 20))
  (description (string-ascii 512))
  (location (string-ascii 256))
)
  (let
    (
      (audit (unwrap! (map-get? audit-summaries audit-id) ERR_AUDIT_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get auditor audit)) ERR_NOT_AUTHORIZED)
    (map-set audit-findings 
      {audit-id: audit-id, finding-index: finding-index}
      {severity: severity, description: description, location: location}
    )
    (ok true)
  )
)

(define-public (verify-audit-signature (audit-id uint))
  (let
    (
      (audit (unwrap! (map-get? audit-summaries audit-id) ERR_AUDIT_NOT_FOUND))
    )
    (if (is-eq (get signature-type audit) "SECP256R1")
      (ok (secp256r1-verify 
        (get audit-hash audit)
        (get signature audit)
        (get public-key audit)
      ))
      (ok false)
    )
  )
)

(define-read-only (get-audit-count)
  (ok (var-get next-audit-id))
)

(define-read-only (check-restriction)
  (ok (is-ok (contract-hash? .audit-report)))
)

(define-read-only (get-timestamp)
  stacks-block-time
)
