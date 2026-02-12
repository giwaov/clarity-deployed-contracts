(define-non-fungible-token referable-nft uint)

(define-data-var token-id-nonce uint u0)
(define-data-var token-name (string-ascii 32) "ReferableNFT")
(define-data-var token-symbol (string-ascii 10) "RNFT")

(define-map referring-map {token-id: uint, contract: principal} (list 200 uint))
(define-map referred-map {token-id: uint, contract: principal} (list 200 uint))
(define-map referring-contracts uint (list 50 principal))
(define-map referred-contracts uint (list 50 principal))
(define-map token-timestamp uint uint)

(define-constant err-owner-only (err u100))
(define-constant err-token-not-found (err u101))
(define-constant err-invalid-reference (err u102))
(define-constant err-self-reference (err u103))
(define-constant err-timestamp-invalid (err u104))

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce)))

(define-read-only (get-token-uri (id uint))
  (ok none))

(define-read-only (get-owner (id uint))
  (ok (nft-get-owner? referable-nft id)))

(define-read-only (get-name)
  (ok (var-get token-name)))

(define-read-only (get-symbol)
  (ok (var-get token-symbol)))

(define-read-only (referring-of (contract-addr principal) (token-id uint))
  (let ((contracts (default-to (list) (map-get? referring-contracts token-id))))
    (ok {contracts: contracts, token-ids: (map get-referring-tokens contracts)})))

(define-read-only (referred-of (contract-addr principal) (token-id uint))
  (let ((contracts (default-to (list) (map-get? referred-contracts token-id))))
    (ok {contracts: contracts, token-ids: (map get-referred-tokens contracts)})))

(define-read-only (created-timestamp-of (contract-addr principal) (token-id uint))
  (ok (default-to u0 (map-get? token-timestamp token-id))))

(define-private (get-referring-tokens (contract-addr principal))
  (default-to (list) (map-get? referring-map {token-id: (var-get token-id-nonce), contract: contract-addr})))

(define-private (get-referred-tokens (contract-addr principal))
  (default-to (list) (map-get? referred-map {token-id: (var-get token-id-nonce), contract: contract-addr})))

(define-public (transfer (id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-owner-only)
    (nft-transfer? referable-nft id sender recipient)))

(define-public (mint (recipient principal))
  (let ((token-id (+ (var-get token-id-nonce) u1)))
    (try! (nft-mint? referable-nft token-id recipient))
    (map-set token-timestamp token-id stacks-block-height)
    (var-set token-id-nonce token-id)
    (ok token-id)))

(define-public (set-node (token-id uint) (addresses (list 50 principal)) (token-ids (list 50 (list 200 uint))))
  (let ((owner (unwrap! (nft-get-owner? referable-nft token-id) err-token-not-found)))
    (asserts! (is-eq tx-sender owner) err-owner-only)
    (begin
      (set-referring token-id addresses token-ids)
      (set-referred token-id addresses token-ids)
      (ok true))))

(define-private (set-referring (token-id uint) (addresses (list 50 principal)) (token-ids (list 50 (list 200 uint))))
  (map-set referring-contracts token-id addresses))

(define-private (set-referring-helper (addr principal) (ids (list 200 uint)))
  (map-set referring-map {token-id: (var-get token-id-nonce), contract: addr} ids))

(define-private (set-referred (token-id uint) (addresses (list 50 principal)) (token-ids (list 50 (list 200 uint))))
  (map-set referred-contracts token-id addresses))
