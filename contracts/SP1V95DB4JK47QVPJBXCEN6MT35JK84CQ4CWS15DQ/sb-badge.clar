(define-non-fungible-token sb-badge uint)

(define-data-var badge-id-nonce uint u0)

(define-map badge-soul {badge-id: uint} {nft-contract: principal, nft-token-id: uint})
(define-map badge-uri uint (string-ascii 256))

(define-constant contract-owner tx-sender)
(define-constant collection-uri "ipfs://collection-metadata")
(define-constant err-not-owner (err u100))
(define-constant err-non-transferable (err u101))
(define-constant err-already-bound (err u102))

(define-read-only (get-last-badge-id)
  (ok (var-get badge-id-nonce)))

(define-read-only (get-owner-of (badge-id uint))
  (ok (unwrap! (map-get? badge-soul {badge-id: badge-id}) err-not-owner)))

(define-read-only (get-collection-uri)
  collection-uri)

(define-read-only (get-badge-uri (badge-id uint))
  (ok (unwrap! (map-get? badge-uri badge-id) err-not-owner)))

(define-public (mint (nft-contract principal) (nft-token-id uint) (uri (string-ascii 256)))
  (let ((new-id (+ (var-get badge-id-nonce) u1)))
    (try! (nft-mint? sb-badge new-id tx-sender))
    (map-set badge-soul {badge-id: new-id} {nft-contract: nft-contract, nft-token-id: nft-token-id})
    (map-set badge-uri new-id uri)
    (var-set badge-id-nonce new-id)
    (ok new-id)))

(define-public (transfer (badge-id uint) (sender principal) (recipient principal))
  err-non-transferable)

(define-read-only (get-contract-hash)
  (contract-hash? .sb-badge))

(define-read-only (get-block-time)
  stacks-block-time)
