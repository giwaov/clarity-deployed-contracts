(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-params (err u103))
(define-constant err-already-exists (err u104))

(define-map enclaves
  {enclave-id: (string-ascii 64)}
  {
    operator: principal,
    attestation-hash: (buff 32),
    public-key: (buff 33),
    verified: bool,
    active: bool,
    created-at: uint
  }
)

(define-map computations
  {computation-id: uint}
  {
    enclave-id: (string-ascii 64),
    requester: principal,
    input-hash: (buff 32),
    output-hash: (optional (buff 32)),
    status: (string-ascii 16),
    created-at: uint,
    completed-at: (optional uint)
  }
)

(define-map data-keys
  {key-id: (buff 32)}
  {
    owner: principal,
    encrypted-key: (buff 128),
    enclave-id: (string-ascii 64),
    active: bool
  }
)

(define-data-var computation-nonce uint u0)

(define-read-only (get-enclave (enclave-id (string-ascii 64)))
  (map-get? enclaves {enclave-id: enclave-id})
)

(define-read-only (get-computation (computation-id uint))
  (map-get? computations {computation-id: computation-id})
)

(define-read-only (get-data-key (key-id (buff 32)))
  (map-get? data-keys {key-id: key-id})
)

(define-public (register-enclave
  (enclave-id (string-ascii 64))
  (attestation-hash (buff 32))
  (public-key (buff 33))
)
  (begin
    (asserts! (is-none (map-get? enclaves {enclave-id: enclave-id})) err-already-exists)
    (ok (map-set enclaves {enclave-id: enclave-id}
      {
        operator: tx-sender,
        attestation-hash: attestation-hash,
        public-key: public-key,
        verified: false,
        active: false,
        created-at: stacks-block-height
      }
    ))
  )
)

(define-public (verify-enclave (enclave-id (string-ascii 64)))
  (let ((enclave (unwrap! (map-get? enclaves {enclave-id: enclave-id}) err-not-found)))
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (ok (map-set enclaves {enclave-id: enclave-id}
      (merge enclave {verified: true, active: true})
    ))
  )
)

(define-public (submit-computation
  (enclave-id (string-ascii 64))
  (input-hash (buff 32))
)
  (let (
    (enclave (unwrap! (map-get? enclaves {enclave-id: enclave-id}) err-not-found))
    (computation-id (var-get computation-nonce))
  )
    (asserts! (get verified enclave) err-unauthorized)
    (asserts! (get active enclave) err-unauthorized)
    (map-set computations {computation-id: computation-id}
      {
        enclave-id: enclave-id,
        requester: tx-sender,
        input-hash: input-hash,
        output-hash: none,
        status: "pending",
        created-at: stacks-block-height,
        completed-at: none
      }
    )
    (var-set computation-nonce (+ computation-id u1))
    (ok computation-id)
  )
)

(define-public (complete-computation
  (computation-id uint)
  (output-hash (buff 32))
)
  (let ((computation (unwrap! (map-get? computations {computation-id: computation-id}) err-not-found)))
    (asserts! (is-eq tx-sender 
      (get operator (unwrap! (map-get? enclaves {enclave-id: (get enclave-id computation)}) err-not-found)))
      err-unauthorized)
    (ok (map-set computations {computation-id: computation-id}
      (merge computation {
        output-hash: (some output-hash),
        status: "completed",
        completed-at: (some stacks-block-height)
      })
    ))
  )
)

(define-public (store-encrypted-key
  (key-id (buff 32))
  (encrypted-key (buff 128))
  (enclave-id (string-ascii 64))
)
  (let ((enclave (unwrap! (map-get? enclaves {enclave-id: enclave-id}) err-not-found)))
    (asserts! (get verified enclave) err-unauthorized)
    (ok (map-set data-keys {key-id: key-id}
      {
        owner: tx-sender,
        encrypted-key: encrypted-key,
        enclave-id: enclave-id,
        active: true
      }
    ))
  )
)

(define-public (revoke-key (key-id (buff 32)))
  (let ((key-data (unwrap! (map-get? data-keys {key-id: key-id}) err-not-found)))
    (asserts! (is-eq tx-sender (get owner key-data)) err-unauthorized)
    (ok (map-set data-keys {key-id: key-id}
      (merge key-data {active: false})
    ))
  )
)

(define-public (deactivate-enclave (enclave-id (string-ascii 64)))
  (let ((enclave (unwrap! (map-get? enclaves {enclave-id: enclave-id}) err-not-found)))
    (asserts! (or 
      (is-eq tx-sender contract-owner)
      (is-eq tx-sender (get operator enclave)))
      err-unauthorized)
    (ok (map-set enclaves {enclave-id: enclave-id}
      (merge enclave {active: false})
    ))
  )
)
