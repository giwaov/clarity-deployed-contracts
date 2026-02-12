(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_PROXY_NOT_FOUND (err u101))
(define-constant ERR_INVALID_IMPLEMENTATION (err u102))
(define-constant ERR_METADATA_TOO_LARGE (err u103))
(define-constant ERR_ALREADY_INITIALIZED (err u104))
(define-constant ERR_INVALID_SIGNATURE (err u105))
(define-constant ERR_EXPIRED (err u106))
(define-constant ERR_INVALID_HASH (err u107))

(define-constant MAX_METADATA_SIZE u1024)

(define-data-var contract-owner principal tx-sender)
(define-data-var proxy-nonce uint u0)

(define-map proxies
  uint
  {
    implementation: principal,
    metadata: (buff 1024),
    metadata-length: uint,
    creator: principal,
    created-at: uint,
    initialized: bool
  }
)

(define-map proxy-by-creator
  principal
  (list 50 uint)
)

(define-map authorized-deployers principal bool)

(define-read-only (get-owner)
  (var-get contract-owner)
)

(define-read-only (get-proxy (proxy-id uint))
  (map-get? proxies proxy-id)
)

(define-read-only (get-proxy-count)
  (var-get proxy-nonce)
)

(define-read-only (get-implementation (proxy-id uint))
  (match (map-get? proxies proxy-id)
    proxy (some (get implementation proxy))
    none
  )
)

(define-read-only (get-metadata (proxy-id uint))
  (match (map-get? proxies proxy-id)
    proxy (some (get metadata proxy))
    none
  )
)

(define-read-only (get-metadata-length (proxy-id uint))
  (match (map-get? proxies proxy-id)
    proxy (some (get metadata-length proxy))
    none
  )
)

(define-read-only (is-initialized (proxy-id uint))
  (match (map-get? proxies proxy-id)
    proxy (get initialized proxy)
    false
  )
)

(define-read-only (get-proxies-by-creator (creator principal))
  (default-to (list) (map-get? proxy-by-creator creator))
)

(define-read-only (is-authorized-deployer (deployer principal))
  (default-to false (map-get? authorized-deployers deployer))
)

(define-read-only (verify-implementation-hash (impl principal) (expected-hash (buff 32)))
  (match (contract-hash? impl)
    hash (is-eq hash expected-hash)
    err-val false
  )
)

(define-read-only (get-current-time)
  stacks-block-time
)

(define-read-only (verify-p256-signature (msg-hash (buff 32)) (sig (buff 64)) (pubkey (buff 33)))
  (secp256r1-verify msg-hash sig pubkey)
)

(define-read-only (metadata-to-ascii (data (buff 128)))
  (to-ascii? data)
)

(define-read-only (encode-proxy-data (proxy-id uint) (impl principal) (metadata (buff 128)))
  {
    proxy-id: proxy-id,
    implementation: impl,
    metadata-ascii: (to-ascii? metadata),
    created-at: stacks-block-time
  }
)

(define-public (create-proxy (implementation principal) (metadata (buff 1024)))
  (let
    (
      (new-id (+ (var-get proxy-nonce) u1))
      (metadata-len (len metadata))
      (creator-proxies (default-to (list) (map-get? proxy-by-creator tx-sender)))
    )
    (asserts! (<= metadata-len MAX_METADATA_SIZE) ERR_METADATA_TOO_LARGE)
    (asserts! (is-ok (contract-hash? implementation)) ERR_INVALID_IMPLEMENTATION)
    (map-set proxies new-id
      {
        implementation: implementation,
        metadata: metadata,
        metadata-length: metadata-len,
        creator: tx-sender,
        created-at: stacks-block-time,
        initialized: false
      }
    )
    (map-set proxy-by-creator tx-sender
      (unwrap-panic (as-max-len? (append creator-proxies new-id) u50))
    )
    (var-set proxy-nonce new-id)
    (ok new-id)
  )
)

(define-public (create-proxy-verified
    (implementation principal)
    (metadata (buff 1024))
    (expected-hash (buff 32))
    (msg-hash (buff 32))
    (sig (buff 64))
    (pubkey (buff 33))
    (deadline uint)
  )
  (let
    (
      (new-id (+ (var-get proxy-nonce) u1))
      (metadata-len (len metadata))
      (creator-proxies (default-to (list) (map-get? proxy-by-creator tx-sender)))
    )
    (asserts! (<= metadata-len MAX_METADATA_SIZE) ERR_METADATA_TOO_LARGE)
    (asserts! (>= deadline stacks-block-time) ERR_EXPIRED)
    (asserts! (secp256r1-verify msg-hash sig pubkey) ERR_INVALID_SIGNATURE)
    (asserts! (verify-implementation-hash implementation expected-hash) ERR_INVALID_HASH)
    (map-set proxies new-id
      {
        implementation: implementation,
        metadata: metadata,
        metadata-length: metadata-len,
        creator: tx-sender,
        created-at: stacks-block-time,
        initialized: false
      }
    )
    (map-set proxy-by-creator tx-sender
      (unwrap-panic (as-max-len? (append creator-proxies new-id) u50))
    )
    (var-set proxy-nonce new-id)
    (ok new-id)
  )
)

(define-public (initialize-proxy (proxy-id uint))
  (let
    (
      (proxy (unwrap! (map-get? proxies proxy-id) ERR_PROXY_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get creator proxy)) ERR_NOT_AUTHORIZED)
    (asserts! (not (get initialized proxy)) ERR_ALREADY_INITIALIZED)
    (map-set proxies proxy-id
      (merge proxy { initialized: true })
    )
    (ok true)
  )
)

(define-public (update-implementation (proxy-id uint) (new-implementation principal))
  (let
    (
      (proxy (unwrap! (map-get? proxies proxy-id) ERR_PROXY_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender (get creator proxy)) ERR_NOT_AUTHORIZED)
    (asserts! (not (get initialized proxy)) ERR_ALREADY_INITIALIZED)
    (asserts! (is-ok (contract-hash? new-implementation)) ERR_INVALID_IMPLEMENTATION)
    (map-set proxies proxy-id
      (merge proxy { implementation: new-implementation })
    )
    (ok true)
  )
)

(define-public (set-authorized-deployer (deployer principal) (authorized bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (map-set authorized-deployers deployer authorized)
    (ok true)
  )
)

(define-public (transfer-ownership (new-owner principal))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (var-set contract-owner new-owner)
    (ok true)
  )
)
