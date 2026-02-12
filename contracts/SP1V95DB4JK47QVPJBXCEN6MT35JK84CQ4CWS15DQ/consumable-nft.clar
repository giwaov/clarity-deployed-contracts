(define-constant ERR_NOT_AUTHORIZED (err u100))
(define-constant ERR_NOT_FOUND (err u101))
(define-constant ERR_ALREADY_CONSUMED (err u102))
(define-constant ERR_NOT_OWNER (err u103))
(define-constant ERR_NOT_CONSUMABLE (err u104))
(define-constant ERR_INVALID_SIGNATURE (err u105))
(define-constant ERR_EXPIRED (err u106))
(define-constant ERR_ZERO_ADDRESS (err u107))

(define-non-fungible-token consumable-nft uint)

(define-data-var contract-owner principal tx-sender)
(define-data-var token-nonce uint u0)
(define-data-var base-uri (string-ascii 256) "")

(define-map token-uri uint (string-utf8 256))
(define-map token-consumed uint bool)
(define-map token-consumed-at uint uint)
(define-map token-consumed-by uint principal)
(define-map consumption-data uint (buff 256))
(define-map authorized-consumers principal bool)

(define-read-only (get-owner)
  (var-get contract-owner)
)

(define-read-only (get-token-count)
  (var-get token-nonce)
)

(define-read-only (get-base-uri)
  (var-get base-uri)
)

(define-read-only (get-token-owner (token-id uint))
  (nft-get-owner? consumable-nft token-id)
)

(define-read-only (get-token-uri (token-id uint))
  (map-get? token-uri token-id)
)

(define-read-only (is-consumed (token-id uint))
  (default-to false (map-get? token-consumed token-id))
)

(define-read-only (get-consumed-at (token-id uint))
  (map-get? token-consumed-at token-id)
)

(define-read-only (get-consumed-by (token-id uint))
  (map-get? token-consumed-by token-id)
)

(define-read-only (get-consumption-data (token-id uint))
  (map-get? consumption-data token-id)
)

(define-read-only (is-authorized-consumer (consumer principal))
  (default-to false (map-get? authorized-consumers consumer))
)

(define-read-only (is-consumable-by (consumer principal) (token-id uint) (amount uint))
  (let
    (
      (owner (nft-get-owner? consumable-nft token-id))
    )
    (and
      (is-some owner)
      (not (is-consumed token-id))
      (is-eq amount u1)
      (or
        (is-eq (some consumer) owner)
        (is-authorized-consumer consumer)
      )
    )
  )
)

(define-read-only (get-current-time)
  stacks-block-time
)

(define-read-only (verify-p256-signature (msg-hash (buff 32)) (sig (buff 64)) (pubkey (buff 33)))
  (secp256r1-verify msg-hash sig pubkey)
)

(define-read-only (data-to-ascii (data (buff 128)))
  (to-ascii? data)
)

(define-read-only (get-token-info (token-id uint))
  {
    owner: (nft-get-owner? consumable-nft token-id),
    uri: (map-get? token-uri token-id),
    consumed: (is-consumed token-id),
    consumed-at: (map-get? token-consumed-at token-id),
    consumed-by: (map-get? token-consumed-by token-id)
  }
)

(define-public (mint (recipient principal) (uri (string-utf8 256)))
  (let
    (
      (new-id (+ (var-get token-nonce) u1))
    )
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (try! (nft-mint? consumable-nft new-id recipient))
    (map-set token-uri new-id uri)
    (var-set token-nonce new-id)
    (ok new-id)
  )
)

(define-public (mint-verified
    (recipient principal)
    (uri (string-utf8 256))
    (msg-hash (buff 32))
    (sig (buff 64))
    (pubkey (buff 33))
    (deadline uint)
  )
  (let
    (
      (new-id (+ (var-get token-nonce) u1))
    )
    (asserts! (>= deadline stacks-block-time) ERR_EXPIRED)
    (asserts! (secp256r1-verify msg-hash sig pubkey) ERR_INVALID_SIGNATURE)
    (try! (nft-mint? consumable-nft new-id recipient))
    (map-set token-uri new-id uri)
    (var-set token-nonce new-id)
    (ok new-id)
  )
)

(define-public (consume (consumer principal) (token-id uint) (amount uint) (data (buff 256)))
  (let
    (
      (owner (unwrap! (nft-get-owner? consumable-nft token-id) ERR_NOT_FOUND))
    )
    (asserts! (is-eq amount u1) ERR_NOT_CONSUMABLE)
    (asserts! (not (is-consumed token-id)) ERR_ALREADY_CONSUMED)
    (asserts! (or
      (is-eq consumer owner)
      (is-eq tx-sender owner)
      (is-authorized-consumer tx-sender)
    ) ERR_NOT_AUTHORIZED)
    (try! (nft-burn? consumable-nft token-id owner))
    (map-set token-consumed token-id true)
    (map-set token-consumed-at token-id stacks-block-time)
    (map-set token-consumed-by token-id consumer)
    (map-set consumption-data token-id data)
    (ok true)
  )
)

(define-public (consume-verified
    (consumer principal)
    (token-id uint)
    (amount uint)
    (data (buff 256))
    (msg-hash (buff 32))
    (sig (buff 64))
    (pubkey (buff 33))
    (deadline uint)
  )
  (let
    (
      (owner (unwrap! (nft-get-owner? consumable-nft token-id) ERR_NOT_FOUND))
    )
    (asserts! (is-eq amount u1) ERR_NOT_CONSUMABLE)
    (asserts! (not (is-consumed token-id)) ERR_ALREADY_CONSUMED)
    (asserts! (>= deadline stacks-block-time) ERR_EXPIRED)
    (asserts! (secp256r1-verify msg-hash sig pubkey) ERR_INVALID_SIGNATURE)
    (try! (nft-burn? consumable-nft token-id owner))
    (map-set token-consumed token-id true)
    (map-set token-consumed-at token-id stacks-block-time)
    (map-set token-consumed-by token-id consumer)
    (map-set consumption-data token-id data)
    (ok true)
  )
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let
    (
      (owner (unwrap! (nft-get-owner? consumable-nft token-id) ERR_NOT_FOUND))
    )
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    (asserts! (is-eq sender owner) ERR_NOT_OWNER)
    (asserts! (not (is-consumed token-id)) ERR_ALREADY_CONSUMED)
    (nft-transfer? consumable-nft token-id sender recipient)
  )
)

(define-public (set-authorized-consumer (consumer principal) (authorized bool))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (map-set authorized-consumers consumer authorized)
    (ok true)
  )
)

(define-public (set-base-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender (var-get contract-owner)) ERR_NOT_AUTHORIZED)
    (var-set base-uri new-uri)
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
