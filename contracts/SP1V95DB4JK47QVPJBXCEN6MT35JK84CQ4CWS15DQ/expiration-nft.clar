(define-non-fungible-token expiration-nft uint)

(define-data-var token-id-nonce uint u0)
(define-constant expiry-type-time-based "TIME_BASED")
(define-constant validity-duration u1000)

(define-map token-expiry uint {start-time: uint, end-time: uint})

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-expired (err u101))
(define-constant err-not-found (err u102))
(define-constant err-zero-address (err u103))

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce)))

(define-read-only (get-owner (token-id uint))
  (ok (unwrap! (nft-get-owner? expiration-nft token-id) err-not-owner)))

(define-read-only (get-expiry-type)
  expiry-type-time-based)

(define-read-only (is-token-expired (token-id uint))
  (match (map-get? token-expiry token-id)
    expiry (>= stacks-block-time (get end-time expiry))
    true))

(define-read-only (get-start-time (token-id uint))
  (ok (get start-time (unwrap! (map-get? token-expiry token-id) err-not-owner))))

(define-read-only (get-end-time (token-id uint))
  (ok (get end-time (unwrap! (map-get? token-expiry token-id) err-not-owner))))

(define-read-only (get-validity-duration)
  validity-duration)

(define-public (mint (recipient principal))
  (let ((new-id (+ (var-get token-id-nonce) u1))
        (current-time stacks-block-time)
        (expiry-time (+ current-time validity-duration)))
    (try! (nft-mint? expiration-nft new-id recipient))
    (map-set token-expiry new-id {start-time: current-time, end-time: expiry-time})
    (var-set token-id-nonce new-id)
    (ok new-id)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-owner)
    (asserts! (not (is-token-expired token-id)) err-expired)
    (asserts! (is-some (nft-get-owner? expiration-nft token-id)) err-not-found)
    (try! (nft-transfer? expiration-nft token-id sender recipient))
    (ok true)))

(define-read-only (get-contract-hash)
  (contract-hash? .expiration-nft))

(define-read-only (get-block-time)
  stacks-block-time)
