(define-non-fungible-token cap-tf-nft uint)

(define-data-var token-id-nonce uint u0)

(define-map token-transfer-count uint uint)
(define-map token-transfer-limit uint uint)

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-transfer-limit-reached (err u101))

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce)))

(define-read-only (get-owner (token-id uint))
  (ok (unwrap! (nft-get-owner? cap-tf-nft token-id) err-not-owner)))

(define-read-only (transfer-count-of (token-id uint))
  (default-to u0 (map-get? token-transfer-count token-id)))

(define-read-only (transfer-limit-of (token-id uint))
  (default-to u10 (map-get? token-transfer-limit token-id)))

(define-public (mint (recipient principal) (limit uint))
  (let ((new-id (+ (var-get token-id-nonce) u1)))
    (try! (nft-mint? cap-tf-nft new-id recipient))
    (map-set token-transfer-count new-id u0)
    (map-set token-transfer-limit new-id limit)
    (var-set token-id-nonce new-id)
    (ok new-id)))

(define-public (set-transfer-limit (token-id uint) (limit uint))
  (let ((owner (unwrap! (nft-get-owner? cap-tf-nft token-id) err-not-owner)))
    (asserts! (is-eq tx-sender owner) err-not-owner)
    (map-set token-transfer-limit token-id limit)
    (ok true)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let ((count (transfer-count-of token-id))
        (limit (transfer-limit-of token-id)))
    (asserts! (is-eq tx-sender sender) err-not-owner)
    (asserts! (< count limit) err-transfer-limit-reached)
    (try! (nft-transfer? cap-tf-nft token-id sender recipient))
    (map-set token-transfer-count token-id (+ count u1))
    (ok true)))

(define-read-only (get-contract-hash)
  (contract-hash? .cap-tf-nft))

(define-read-only (get-block-time)
  stacks-block-time)
