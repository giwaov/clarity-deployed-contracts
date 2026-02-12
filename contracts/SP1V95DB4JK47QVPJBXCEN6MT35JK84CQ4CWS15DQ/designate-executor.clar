(define-non-fungible-token designate-executor-token uint)

(define-data-var token-id-nonce uint u0)
(define-constant moratorium-period u2592000)

(define-map token-will uint {executors: (list 10 principal), moratorium-ttl: uint})
(define-map obituary-status {token-id: uint, owner: principal} {announced: bool, inheritor: (optional principal), announcement-time: uint})

(define-constant contract-owner tx-sender)
(define-constant err-not-owner (err u100))
(define-constant err-moratorium-active (err u101))
(define-constant err-no-obituary (err u102))
(define-constant err-zero-address (err u103))

(define-read-only (get-last-token-id)
  (ok (var-get token-id-nonce)))

(define-read-only (get-owner (token-id uint))
  (ok (unwrap! (nft-get-owner? designate-executor-token token-id) err-not-owner)))

(define-read-only (get-will (token-id uint))
  (ok (map-get? token-will token-id)))

(define-read-only (get-obituary (token-id uint) (owner principal))
  (ok (map-get? obituary-status {token-id: token-id, owner: owner})))

(define-public (mint (recipient principal))
  (let ((new-id (+ (var-get token-id-nonce) u1)))
    (try! (nft-mint? designate-executor-token new-id recipient))
    (var-set token-id-nonce new-id)
    (ok new-id)))

(define-public (set-will (token-id uint) (executors (list 10 principal)) (moratorium-ttl uint))
  (let ((owner (unwrap! (nft-get-owner? designate-executor-token token-id) err-not-owner)))
    (asserts! (is-eq tx-sender owner) err-not-owner)
    (map-set token-will token-id {executors: executors, moratorium-ttl: moratorium-ttl})
    (ok true)))

(define-public (announce-obit (token-id uint) (owner principal) (inheritor principal))
  (begin
    (asserts! (is-some (nft-get-owner? designate-executor-token token-id)) err-not-owner)
    (asserts! (is-eq tx-sender owner) err-not-owner)
    (map-set obituary-status {token-id: token-id, owner: owner} 
      {announced: true, inheritor: (some inheritor), announcement-time: stacks-block-time})
    (ok true)))

(define-public (cancel-obit (token-id uint))
  (let ((owner (unwrap! (nft-get-owner? designate-executor-token token-id) err-not-owner)))
    (asserts! (is-eq tx-sender owner) err-not-owner)
    (map-delete obituary-status {token-id: token-id, owner: owner})
    (ok true)))

(define-public (bequeath (token-id uint) (owner principal))
  (let ((obit (unwrap! (map-get? obituary-status {token-id: token-id, owner: owner}) err-no-obituary))
        (will (unwrap! (map-get? token-will token-id) err-no-obituary))
        (inheritor (unwrap! (get inheritor obit) err-no-obituary)))
    (asserts! (>= (- stacks-block-time (get announcement-time obit)) (get moratorium-ttl will)) err-moratorium-active)
    (try! (nft-transfer? designate-executor-token token-id owner inheritor))
    (map-delete obituary-status {token-id: token-id, owner: owner})
    (ok true)))

(define-read-only (get-contract-hash)
  (contract-hash? .designate-executor))

(define-read-only (get-block-time)
  stacks-block-time)
