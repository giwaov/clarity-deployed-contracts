(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-already-exists (err u103))
(define-constant err-invalid-amount (err u104))
(define-constant err-verification-failed (err u105))

(define-data-var kyc-nonce uint u0)

(define-map kyc-records
  principal
  {
    kyc-id: uint,
    verification-level: (string-ascii 20),
    verified-by: principal,
    verification-hash: (buff 32),
    verification-date: uint,
    expiry-date: uint,
    status: (string-ascii 20),
    jurisdiction: (string-ascii 30)
  }
)

(define-map verification-providers
  principal
  {
    provider-name: (string-ascii 50),
    credentials-hash: (buff 32),
    verified: bool,
    total-verifications: uint,
    active: bool
  }
)

(define-map kyc-updates
  {user: principal, update-id: uint}
  {
    previous-status: (string-ascii 20),
    new-status: (string-ascii 20),
    updated-by: principal,
    update-date: uint,
    reason-hash: (buff 32)
  }
)

(define-map provider-verifications principal (list 200 principal))
(define-map update-count principal uint)

(define-public (register-verification-provider (provider-name (string-ascii 50)) (credentials-hash (buff 32)))
  (begin
    (asserts! (is-none (map-get? verification-providers tx-sender)) err-already-exists)
    (map-set verification-providers tx-sender
      {
        provider-name: provider-name,
        credentials-hash: credentials-hash,
        verified: false,
        total-verifications: u0,
        active: false
      }
    )
    (ok true)
  )
)

(define-public (verify-provider (provider principal))
  (let
    (
      (provider-info (unwrap! (map-get? verification-providers provider) err-not-found))
    )
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (map-set verification-providers provider (merge provider-info {
      verified: true,
      active: true
    }))
    (ok true)
  )
)

(define-public (submit-kyc (user principal) (verification-level (string-ascii 20)) (verification-hash (buff 32)) (jurisdiction (string-ascii 30)) (duration-blocks uint))
  (let
    (
      (provider (unwrap! (map-get? verification-providers tx-sender) err-not-found))
      (kyc-id (+ (var-get kyc-nonce) u1))
    )
    (asserts! (get active provider) err-unauthorized)
    (asserts! (get verified provider) err-verification-failed)
    (asserts! (is-none (map-get? kyc-records user)) err-already-exists)
    (map-set kyc-records user
      {
        kyc-id: kyc-id,
        verification-level: verification-level,
        verified-by: tx-sender,
        verification-hash: verification-hash,
        verification-date: stacks-block-height,
        expiry-date: (+ stacks-block-height duration-blocks),
        status: "verified",
        jurisdiction: jurisdiction
      }
    )
    (map-set verification-providers tx-sender (merge provider {
      total-verifications: (+ (get total-verifications provider) u1)
    }))
    (map-set provider-verifications tx-sender
      (unwrap-panic (as-max-len? (append (default-to (list) (map-get? provider-verifications tx-sender)) user) u200)))
    (map-set update-count user u0)
    (var-set kyc-nonce kyc-id)
    (ok kyc-id)
  )
)

(define-public (update-kyc-status (user principal) (new-status (string-ascii 20)) (reason-hash (buff 32)))
  (let
    (
      (kyc (unwrap! (map-get? kyc-records user) err-not-found))
      (provider (unwrap! (map-get? verification-providers tx-sender) err-not-found))
      (update-id (+ (default-to u0 (map-get? update-count user)) u1))
    )
    (asserts! (get active provider) err-unauthorized)
    (asserts! (is-eq (get verified-by kyc) tx-sender) err-unauthorized)
    (map-set kyc-updates {user: user, update-id: update-id}
      {
        previous-status: (get status kyc),
        new-status: new-status,
        updated-by: tx-sender,
        update-date: stacks-block-height,
        reason-hash: reason-hash
      }
    )
    (map-set kyc-records user (merge kyc {status: new-status}))
    (map-set update-count user update-id)
    (ok true)
  )
)

(define-public (renew-kyc (user principal) (duration-blocks uint))
  (let
    (
      (kyc (unwrap! (map-get? kyc-records user) err-not-found))
      (provider (unwrap! (map-get? verification-providers tx-sender) err-not-found))
    )
    (asserts! (get active provider) err-unauthorized)
    (asserts! (is-eq (get verified-by kyc) tx-sender) err-unauthorized)
    (map-set kyc-records user (merge kyc {
      expiry-date: (+ stacks-block-height duration-blocks),
      verification-date: stacks-block-height
    }))
    (ok true)
  )
)

(define-public (revoke-kyc (user principal) (reason-hash (buff 32)))
  (let
    (
      (kyc (unwrap! (map-get? kyc-records user) err-not-found))
      (provider (unwrap! (map-get? verification-providers tx-sender) err-not-found))
      (update-id (+ (default-to u0 (map-get? update-count user)) u1))
    )
    (asserts! (get active provider) err-unauthorized)
    (asserts! (is-eq (get verified-by kyc) tx-sender) err-unauthorized)
    (map-set kyc-updates {user: user, update-id: update-id}
      {
        previous-status: (get status kyc),
        new-status: "revoked",
        updated-by: tx-sender,
        update-date: stacks-block-height,
        reason-hash: reason-hash
      }
    )
    (map-set kyc-records user (merge kyc {status: "revoked"}))
    (map-set update-count user update-id)
    (ok true)
  )
)

(define-read-only (get-kyc-record (user principal))
  (ok (map-get? kyc-records user))
)

(define-read-only (get-verification-provider (provider principal))
  (ok (map-get? verification-providers provider))
)

(define-read-only (get-kyc-update (user principal) (update-id uint))
  (ok (map-get? kyc-updates {user: user, update-id: update-id}))
)

(define-read-only (get-provider-verifications (provider principal))
  (ok (map-get? provider-verifications provider))
)

(define-read-only (is-kyc-valid (user principal))
  (let
    (
      (kyc (unwrap! (map-get? kyc-records user) err-not-found))
    )
    (ok (and
      (is-eq (get status kyc) "verified")
      (<= stacks-block-height (get expiry-date kyc))
    ))
  )
)
