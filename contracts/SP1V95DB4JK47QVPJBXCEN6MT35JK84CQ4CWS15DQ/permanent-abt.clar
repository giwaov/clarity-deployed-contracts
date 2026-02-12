(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1600))
(define-constant ERR_TOKEN_NOT_FOUND (err u1601))
(define-constant ERR_CANNOT_TRANSFER (err u1602))

(define-non-fungible-token permanent-abt uint)

(define-data-var next-token-id uint u1)

(define-map token-metadata
  uint
  {
    holder: principal,
    issuer: principal,
    credential-type: (string-ascii 128),
    issued-at: uint,
    revoked: bool,
    attributes: (buff 512)
  }
)

(define-map holder-tokens
  principal
  (list 50 uint)
)

(define-read-only (get-contract-hash)
  (contract-hash? .permanent-abt)
)

(define-read-only (get-token-owner (token-id uint))
  (ok (nft-get-owner? permanent-abt token-id))
)

(define-read-only (get-token-metadata (token-id uint))
  (ok (unwrap! (map-get? token-metadata token-id) ERR_TOKEN_NOT_FOUND))
)

(define-read-only (get-holder-tokens (holder principal))
  (ok (default-to (list) (map-get? holder-tokens holder)))
)

(define-public (mint-abt 
  (to principal)
  (credential-type (string-ascii 128))
  (attributes (buff 512))
)
  (let
    (
      (token-id (var-get next-token-id))
    )
    (try! (nft-mint? permanent-abt token-id to))
    (map-set token-metadata token-id {
      holder: to,
      issuer: tx-sender,
      credential-type: credential-type,
      issued-at: stacks-block-time,
      revoked: false,
      attributes: attributes
    })
    (let
      (
        (current-tokens (default-to (list) (map-get? holder-tokens to)))
      )
      (map-set holder-tokens to (unwrap-panic (as-max-len? (append current-tokens token-id) u50)))
    )
    (var-set next-token-id (+ token-id u1))
    (ok token-id)
  )
)

(define-public (revoke-abt (token-id uint))
  (let
    (
      (token-data (unwrap! (map-get? token-metadata token-id) ERR_TOKEN_NOT_FOUND))
    )
    (asserts! (is-eq (get issuer token-data) tx-sender) ERR_NOT_AUTHORIZED)
    (map-set token-metadata token-id (merge token-data {revoked: true}))
    (ok true)
  )
)

(define-public (update-attributes (token-id uint) (new-attributes (buff 512)))
  (let
    (
      (token-data (unwrap! (map-get? token-metadata token-id) ERR_TOKEN_NOT_FOUND))
    )
    (asserts! (is-eq (get issuer token-data) tx-sender) ERR_NOT_AUTHORIZED)
    (map-set token-metadata token-id (merge token-data {attributes: new-attributes}))
    (ok true)
  )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (err ERR_CANNOT_TRANSFER)
  )
)

(define-read-only (verify-credential (token-id uint))
  (let
    (
      (token-data (unwrap! (map-get? token-metadata token-id) ERR_TOKEN_NOT_FOUND))
    )
    (ok (and (not (get revoked token-data)) (is-some (nft-get-owner? permanent-abt token-id))))
  )
)

(define-read-only (verify-r1-signature (message (buff 32)) (signature (buff 64)) (public-key (buff 33)))
  (ok (secp256r1-verify message signature public-key))
)

(define-read-only (get-time)
  stacks-block-time
)

(define-read-only (check-restrictions)
  (ok (is-ok (contract-hash? .permanent-abt)))
)
