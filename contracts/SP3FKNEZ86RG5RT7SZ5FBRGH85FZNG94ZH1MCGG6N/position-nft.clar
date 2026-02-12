;; Position NFT - SIP-009 NFT for Time-Locked Positions

;; Define NFT trait locally
(define-trait nft-trait
  (
    (get-last-token-id () (response uint uint))
    (get-token-uri (uint) (response (optional (string-ascii 256)) uint))
    (get-owner (uint) (response (optional principal) uint))
    (transfer (uint principal principal) (response bool uint))
  ))

;; Token name
(define-non-fungible-token position uint)

;; Storage
(define-data-var last-token-id uint u0)
(define-data-var token-uri (string-ascii 256) "https://timelock-exchange.com/metadata/")

;; Constants
(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_NOT_AUTHORIZED (err u401))
(define-constant ERR_NOT_FOUND (err u404))
(define-constant ERR_ALREADY_EXISTS (err u409))

;; SIP-009 Functions

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id)))

(define-read-only (get-token-uri (token-id uint))
  (ok (some (var-get token-uri))))

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? position token-id)))

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR_NOT_AUTHORIZED)
    (nft-transfer? position token-id sender recipient)))

;; Mint function (called by exchange contract)
(define-public (mint (recipient principal))
  (let ((token-id (+ (var-get last-token-id) u1)))
    (try! (nft-mint? position token-id recipient))
    (var-set last-token-id token-id)
    (ok token-id)))

;; Burn function (called when position is closed)
(define-public (burn (token-id uint))
  (let ((owner (unwrap! (nft-get-owner? position token-id) ERR_NOT_FOUND)))
    (asserts! (is-eq tx-sender owner) ERR_NOT_AUTHORIZED)
    (nft-burn? position token-id owner)))

;; Admin function to update URI
(define-public (set-token-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT_OWNER) ERR_NOT_AUTHORIZED)
    (var-set token-uri new-uri)
    (ok true)))
