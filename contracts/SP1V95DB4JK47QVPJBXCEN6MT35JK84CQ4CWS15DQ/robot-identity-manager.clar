(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u300))
(define-constant ERR_RULE_NOT_FOUND (err u301))
(define-constant ERR_INVALID_CHALLENGE (err u302))
(define-constant ERR_INVALID_SIGNATURE (err u303))
(define-constant ERR_CHARTER_NOT_FOUND (err u304))

(define-data-var next-robot-id uint u1)
(define-data-var next-charter-id uint u1)

(define-map robot-identities
  uint
  {
    owner: principal,
    public-key: (buff 33),
    manufacturer: (string-ascii 128),
    operator: (string-ascii 128),
    model: (string-ascii 128),
    serial-number: (string-ascii 128),
    initial-hash: (buff 32),
    current-hash: (buff 32),
    created-at: uint
  }
)

(define-map robot-rules
  {robot-id: uint, rule-hash: (buff 32)}
  bool
)

(define-map robot-compliance
  {robot-id: uint, rule-hash: (buff 32)}
  bool
)

(define-map active-challenges
  (buff 32)
  {robot-id: uint, created-at: uint, used: bool}
)

(define-map charter-subscriptions
  {robot-id: uint, charter: principal}
  bool
)

(define-map charter-rules
  {charter: principal, version: uint}
  (list 50 (buff 32))
)

(define-map charter-users
  {charter: principal, user: principal}
  {user-type: (string-ascii 10), registered: bool, rule-version: uint}
)

(define-read-only (get-contract-hash)
  (contract-hash? .robot-identity-manager)
)

(define-read-only (get-robot-identity (robot-id uint))
  (ok (unwrap! (map-get? robot-identities robot-id) ERR_NOT_AUTHORIZED))
)

(define-public (create-robot-identity 
  (public-key (buff 33))
  (manufacturer (string-ascii 128))
  (operator (string-ascii 128))
  (model (string-ascii 128))
  (serial-number (string-ascii 128))
  (initial-hash (buff 32))
)
  (let
    (
      (robot-id (var-get next-robot-id))
    )
    (map-set robot-identities robot-id {
      owner: tx-sender,
      public-key: public-key,
      manufacturer: manufacturer,
      operator: operator,
      model: model,
      serial-number: serial-number,
      initial-hash: initial-hash,
      current-hash: initial-hash,
      created-at: stacks-block-time
    })
    (var-set next-robot-id (+ robot-id u1))
    (ok robot-id)
  )
)

(define-public (generate-challenge (robot-id uint))
  (let
    (
      (robot-data (unwrap! (map-get? robot-identities robot-id) ERR_NOT_AUTHORIZED))
      (challenge-hash (keccak256 (concat (unwrap-panic (contract-hash? .robot-identity-manager)) (unwrap-panic (to-consensus-buff? stacks-block-height)))))
    )
    (map-set active-challenges challenge-hash {
      robot-id: robot-id,
      created-at: stacks-block-height,
      used: false
    })
    (ok challenge-hash)
  )
)

(define-public (verify-challenge (challenge (buff 32)) (signature (buff 64)) (robot-id uint))
  (let
    (
      (robot-data (unwrap! (map-get? robot-identities robot-id) ERR_NOT_AUTHORIZED))
      (challenge-data (unwrap! (map-get? active-challenges challenge) ERR_INVALID_CHALLENGE))
    )
    (asserts! (not (get used challenge-data)) ERR_INVALID_CHALLENGE)
    (asserts! (is-eq (get robot-id challenge-data) robot-id) ERR_INVALID_CHALLENGE)
    (asserts! (secp256r1-verify challenge signature (get public-key robot-data)) ERR_INVALID_SIGNATURE)
    (map-set active-challenges challenge (merge challenge-data {used: true}))
    (ok true)
  )
)

(define-public (add-rule (robot-id uint) (rule (buff 32)))
  (let
    (
      (robot-data (unwrap! (map-get? robot-identities robot-id) ERR_NOT_AUTHORIZED))
    )
    (asserts! (is-eq (get owner robot-data) tx-sender) ERR_NOT_AUTHORIZED)
    (map-set robot-rules {robot-id: robot-id, rule-hash: rule} true)
    (ok true)
  )
)

(define-public (remove-rule (robot-id uint) (rule (buff 32)))
  (let
    (
      (robot-data (unwrap! (map-get? robot-identities robot-id) ERR_NOT_AUTHORIZED))
    )
    (asserts! (is-eq (get owner robot-data) tx-sender) ERR_NOT_AUTHORIZED)
    (map-set robot-rules {robot-id: robot-id, rule-hash: rule} false)
    (map-set robot-compliance {robot-id: robot-id, rule-hash: rule} false)
    (ok true)
  )
)

(define-read-only (check-compliance (robot-id uint) (rule (buff 32)))
  (ok (default-to false (map-get? robot-rules {robot-id: robot-id, rule-hash: rule})))
)

(define-public (update-compliance (robot-id uint) (rule (buff 32)) (status bool))
  (let
    (
      (robot-data (unwrap! (map-get? robot-identities robot-id) ERR_NOT_AUTHORIZED))
    )
    (asserts! (is-eq (get owner robot-data) tx-sender) ERR_NOT_AUTHORIZED)
    (map-set robot-compliance {robot-id: robot-id, rule-hash: rule} status)
    (ok true)
  )
)

(define-public (subscribe-to-charter (robot-id uint) (charter principal))
  (let
    (
      (robot-data (unwrap! (map-get? robot-identities robot-id) ERR_NOT_AUTHORIZED))
    )
    (asserts! (is-eq (get owner robot-data) tx-sender) ERR_NOT_AUTHORIZED)
    (map-set charter-subscriptions {robot-id: robot-id, charter: charter} true)
    (ok true)
  )
)

(define-public (unsubscribe-from-charter (robot-id uint) (charter principal))
  (let
    (
      (robot-data (unwrap! (map-get? robot-identities robot-id) ERR_NOT_AUTHORIZED))
    )
    (asserts! (is-eq (get owner robot-data) tx-sender) ERR_NOT_AUTHORIZED)
    (map-set charter-subscriptions {robot-id: robot-id, charter: charter} false)
    (ok true)
  )
)

(define-public (update-hardware-hash (robot-id uint) (new-hash (buff 32)))
  (let
    (
      (robot-data (unwrap! (map-get? robot-identities robot-id) ERR_NOT_AUTHORIZED))
    )
    (asserts! (is-eq (get owner robot-data) tx-sender) ERR_NOT_AUTHORIZED)
    (map-set robot-identities robot-id (merge robot-data {current-hash: new-hash}))
    (ok true)
  )
)

(define-public (register-user-to-charter 
  (charter principal)
  (user-type (string-ascii 10))
  (rule-version uint)
)
  (begin
    (map-set charter-users 
      {charter: charter, user: tx-sender}
      {user-type: user-type, registered: true, rule-version: rule-version}
    )
    (ok true)
  )
)

(define-public (leave-charter (charter principal))
  (begin
    (map-set charter-users 
      {charter: charter, user: tx-sender}
      {user-type: "None", registered: false, rule-version: u0}
    )
    (ok true)
  )
)

(define-read-only (asset-restriction-check)
  (ok (is-ok (contract-hash? .robot-identity-manager)))
)
