(define-non-fungible-token soulbound-nft uint)

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u1001))
(define-constant ERR_TOKEN_NOT_FOUND (err u1002))
(define-constant ERR_TRANSFER_LOCKED (err u1003))
(define-constant ERR_INVALID_SIGNATURE (err u1004))
(define-constant ERR_ZERO_ADDRESS (err u1005))

(define-data-var token-counter uint u0)
(define-data-var base-uri (string-ascii 64) "https://api.bitto.io/sbt/")

(define-map token-data uint {
  owner: principal,
  uri: (string-utf8 64),
  locked: bool,
  minted-at: uint
})

(define-map minters principal bool)

(define-read-only (locked (token-id uint))
  (match (map-get? token-data token-id)
    data (ok (get locked data))
    ERR_TOKEN_NOT_FOUND))

(define-read-only (get-owner (token-id uint))
  (nft-get-owner? soulbound-nft token-id))

(define-read-only (get-token-uri (token-id uint))
  (match (map-get? token-data token-id)
    data (some (get uri data))
    none))

(define-read-only (get-token-count)
  (var-get token-counter))

(define-read-only (get-current-time)
  stacks-block-time)

(define-read-only (get-contract-hash)
  (contract-hash? tx-sender))

(define-read-only (get-base-uri)
  (var-get base-uri))

(define-read-only (is-minter (account principal))
  (default-to false (map-get? minters account)))

(define-read-only (verify-p256 (msg (buff 32)) (sig (buff 64)) (pk (buff 33)))
  (secp256r1-verify msg sig pk))

(define-read-only (uri-to-ascii (input (string-utf8 64)))
  (to-ascii? input))

(define-public (mint (to principal) (uri (string-utf8 64)))
  (let ((id (+ (var-get token-counter) u1)))
    (try! (nft-mint? soulbound-nft id to))
    (map-set token-data id {
      owner: to,
      uri: uri,
      locked: true,
      minted-at: stacks-block-time
    })
    (var-set token-counter id)
    (print { event: "Locked", token-id: id })
    (ok id)))

(define-public (mint-verified (to principal) (uri (string-utf8 64)) (msg (buff 32)) (sig (buff 64)) (pk (buff 33)))
  (begin
    (asserts! (secp256r1-verify msg sig pk) ERR_INVALID_SIGNATURE)
    (mint to uri)))

(define-public (burn (id uint))
  (let ((data (unwrap! (map-get? token-data id) ERR_TOKEN_NOT_FOUND)))
    (asserts! (is-eq tx-sender (get owner data)) ERR_NOT_AUTHORIZED)
    (try! (nft-burn? soulbound-nft id tx-sender))
    (map-delete token-data id)
    (ok true)))

(define-public (unlock (id uint))
  (let ((data (unwrap! (map-get? token-data id) ERR_TOKEN_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set token-data id (merge data { locked: false }))
    (print { event: "Unlocked", token-id: id })
    (ok true)))

(define-public (lock (id uint))
  (let ((data (unwrap! (map-get? token-data id) ERR_TOKEN_NOT_FOUND)))
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set token-data id (merge data { locked: true }))
    (print { event: "Locked", token-id: id })
    (ok true)))

(define-public (transfer (id uint) (from principal) (to principal))
  (let ((data (unwrap! (map-get? token-data id) ERR_TOKEN_NOT_FOUND)))
    (asserts! (not (get locked data)) ERR_TRANSFER_LOCKED)
    (asserts! (is-eq tx-sender from) ERR_NOT_AUTHORIZED)
    (try! (nft-transfer? soulbound-nft id from to))
    (map-set token-data id (merge data { owner: to }))
    (ok true)))

(define-public (set-minter (account principal) (status bool))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (map-set minters account status)
    (ok true)))

(define-public (set-base-uri (uri (string-ascii 64)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set base-uri uri)
    (ok true)))
