(define-non-fungible-token acc-bounded-token uint)

(define-data-var token-id-nonce uint u0)

(define-map token-metadata uint {uri: (string-ascii 256), metadata: (buff 256)})
(define-map token-agreement {token-id: uint} {from: principal, to: principal, signature: (buff 64)})

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-non-transferable (err u101))
(define-constant err-invalid-agreement (err u102))

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce)))

(define-read-only (get-owner (token-id uint))
  (ok (unwrap! (nft-get-owner? acc-bounded-token token-id) err-not-owner)))

(define-read-only (get-token-metadata (token-id uint))
  (ok (unwrap! (map-get? token-metadata token-id) err-not-owner)))

(define-public (give (to principal) (metadata (buff 256)) (signature (buff 64)) (uri (string-ascii 256)))
  (let ((new-id (+ (var-get token-id-nonce) u1)))
    (try! (nft-mint? acc-bounded-token new-id to))
    (map-set token-metadata new-id {uri: uri, metadata: metadata})
    (map-set token-agreement {token-id: new-id} {from: tx-sender, to: to, signature: signature})
    (var-set token-id-nonce new-id)
    (ok new-id)))

(define-public (take (from principal) (metadata (buff 256)) (signature (buff 64)) (uri (string-ascii 256)))
  (let ((new-id (+ (var-get token-id-nonce) u1)))
    (try! (nft-mint? acc-bounded-token new-id tx-sender))
    (map-set token-metadata new-id {uri: uri, metadata: metadata})
    (map-set token-agreement {token-id: new-id} {from: from, to: tx-sender, signature: signature})
    (var-set token-id-nonce new-id)
    (ok new-id)))

(define-public (unequip (token-id uint))
  (let ((owner (unwrap! (nft-get-owner? acc-bounded-token token-id) err-not-owner)))
    (asserts! (is-eq tx-sender owner) err-not-owner)
    (try! (nft-burn? acc-bounded-token token-id owner))
    (ok true)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  err-non-transferable)

(define-read-only (get-contract-hash)
  (contract-hash? .acc-bounded-token))

(define-read-only (get-block-time)
  stacks-block-time)
