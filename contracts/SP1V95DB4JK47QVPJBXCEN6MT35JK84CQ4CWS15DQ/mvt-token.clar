(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1800))
(define-constant ERR_INSUFFICIENT_BALANCE (err u1801))
(define-constant ERR_NOT_MEMBER (err u1802))

(define-fungible-token mvt-token)

(define-data-var organization-name (string-ascii 128) "")

(define-map member-status
  principal
  {
    is-member: bool,
    role: (string-ascii 64),
    joined-at: uint,
    attribute-value: uint
  }
)

(define-map attribute-requirements
  (string-ascii 64)
  uint
)

(define-read-only (get-contract-hash)
  (contract-hash? .mvt-token)
)

(define-read-only (get-balance (account principal))
  (ok (ft-get-balance mvt-token account))
)

(define-read-only (get-total-supply)
  (ok (ft-get-supply mvt-token))
)

(define-read-only (is-member (account principal))
  (let
    (
      (status (default-to {is-member: false, role: "", joined-at: u0, attribute-value: u0} (map-get? member-status account)))
    )
    (ok (get is-member status))
  )
)

(define-read-only (get-member-info (account principal))
  (ok (map-get? member-status account))
)

(define-public (assign-to (account principal) (role (string-ascii 64)) (attribute-value uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set member-status account {
      is-member: true,
      role: role,
      joined-at: stacks-block-time,
      attribute-value: attribute-value
    })
    (try! (ft-mint? mvt-token u1 account))
    (ok true)
  )
)

(define-public (revoke-from (account principal))
  (let
    (
      (status (unwrap! (map-get? member-status account) ERR_NOT_MEMBER))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set member-status account (merge status {is-member: false}))
    (try! (ft-burn? mvt-token u1 account))
    (ok true)
  )
)

(define-public (modify-attribute (account principal) (new-value uint))
  (let
    (
      (status (unwrap! (map-get? member-status account) ERR_NOT_MEMBER))
    )
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set member-status account (merge status {attribute-value: new-value}))
    (ok true)
  )
)

(define-public (request-role (role (string-ascii 64)))
  (let
    (
      (status (default-to {is-member: false, role: "", joined-at: u0, attribute-value: u0} (map-get? member-status tx-sender)))
      (requirement (default-to u0 (map-get? attribute-requirements role)))
    )
    (asserts! (get is-member status) ERR_NOT_MEMBER)
    (asserts! (>= (get attribute-value status) requirement) ERR_NOT_AUTHORIZED)
    (map-set member-status tx-sender (merge status {role: role}))
    (ok true)
  )
)

(define-public (set-requirement (role (string-ascii 64)) (min-attribute uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set attribute-requirements role min-attribute)
    (ok true)
  )
)

(define-public (transfer (amount uint) (sender principal) (recipient principal))
  (err ERR_NOT_AUTHORIZED)
)

(define-read-only (verify-secp256r1-sig (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (ok (secp256r1-verify message signature public-key))
)

(define-read-only (get-timestamp)
  stacks-block-time
)

(define-read-only (asset-restrictions)
  (ok (is-ok (contract-hash? .mvt-token)))
)
