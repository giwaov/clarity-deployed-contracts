(define-non-fungible-token shared-ownership-nft uint)

(define-data-var token-id-nonce uint u0)

(define-map token-owners {token-id: uint, owner: principal} bool)
(define-map token-provider uint principal)
(define-map token-transfer-value uint uint)
(define-map token-archived {token-id: uint, owner: principal} bool)
(define-map token-metadata uint {uri: (string-ascii 256)})

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-already-owner (err u101))
(define-constant err-archived (err u102))
(define-constant err-not-provider (err u103))
(define-constant err-zero-address (err u104))

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce)))

(define-read-only (get-owner-at-index (token-id uint) (owner principal))
  (default-to false (map-get? token-owners {token-id: token-id, owner: owner})))

(define-read-only (get-provider (token-id uint))
  (ok (default-to tx-sender (map-get? token-provider token-id))))

(define-read-only (get-transfer-value (token-id uint))
  (ok (default-to u0 (map-get? token-transfer-value token-id))))

(define-read-only (is-archived (token-id uint) (owner principal))
  (default-to false (map-get? token-archived {token-id: token-id, owner: owner})))

(define-read-only (get-token-uri (token-id uint))
  (ok (get uri (unwrap! (map-get? token-metadata token-id) err-not-owner))))

(define-public (mint (uri (string-ascii 256)))
  (let ((new-id (+ (var-get token-id-nonce) u1)))
    (try! (nft-mint? shared-ownership-nft new-id tx-sender))
    (map-set token-owners {token-id: new-id, owner: tx-sender} true)
    (map-set token-provider new-id tx-sender)
    (map-set token-transfer-value new-id u0)
    (map-set token-metadata new-id {uri: uri})
    (var-set token-id-nonce new-id)
    (ok new-id)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-owner)
    (asserts! (get-owner-at-index token-id sender) err-not-owner)
    (asserts! (not (is-archived token-id sender)) err-archived)
    (asserts! (not (get-owner-at-index token-id recipient)) err-already-owner)
    (map-set token-owners {token-id: token-id, owner: recipient} true)
    (ok true)))

(define-public (archive (token-id uint))
  (begin
    (asserts! (get-owner-at-index token-id tx-sender) err-not-owner)
    (asserts! (not (is-archived token-id tx-sender)) err-archived)
    (map-set token-archived {token-id: token-id, owner: tx-sender} true)
    (ok true)))

(define-public (set-transfer-value (token-id uint) (new-value uint))
  (let ((provider (unwrap! (map-get? token-provider token-id) err-not-provider)))
    (asserts! (is-eq tx-sender provider) err-not-provider)
    (map-set token-transfer-value token-id new-value)
    (ok true)))

(define-read-only (get-contract-hash)
  (contract-hash? .shared-ownership-nft))

(define-read-only (get-block-time)
  stacks-block-time)
