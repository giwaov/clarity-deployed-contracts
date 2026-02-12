---
title: "Trait simple-nft"
draft: true
---
```
;; Simple NFT Contract (SIP-009 compatible)
;; A basic non-fungible token implementation

(define-non-fungible-token simple-nft uint)

(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-not-token-owner (err u101))
(define-constant err-token-exists (err u102))
(define-constant err-token-not-found (err u103))

(define-data-var last-token-id uint u0)
(define-data-var base-uri (string-ascii 256) "https://api.example.com/nft/")

(define-map token-uris uint (string-ascii 256))

;; SIP-009 Interface
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (map-get? token-uris token-id))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? simple-nft token-id))
)

;; Transfer NFT
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) err-not-token-owner)
    (asserts! (is-some (nft-get-owner? simple-nft token-id)) err-token-not-found)
    (nft-transfer? simple-nft token-id sender recipient)
  )
)

;; Mint NFT (owner only)
(define-public (mint (recipient principal))
  (let ((token-id (+ (var-get last-token-id) u1)))
    (begin
      (asserts! (is-eq tx-sender contract-owner) err-owner-only)
      (try! (nft-mint? simple-nft token-id recipient))
      (var-set last-token-id token-id)
      (ok token-id)
    )
  )
)

;; Mint with custom URI
(define-public (mint-with-uri (recipient principal) (uri (string-ascii 256)))
  (let ((token-id (+ (var-get last-token-id) u1)))
    (begin
      (asserts! (is-eq tx-sender contract-owner) err-owner-only)
      (try! (nft-mint? simple-nft token-id recipient))
      (map-set token-uris token-id uri)
      (var-set last-token-id token-id)
      (ok token-id)
    )
  )
)

;; Public mint (anyone can mint)
(define-public (public-mint)
  (let ((token-id (+ (var-get last-token-id) u1)))
    (begin
      (try! (nft-mint? simple-nft token-id tx-sender))
      (var-set last-token-id token-id)
      (ok token-id)
    )
  )
)

;; Burn NFT
(define-public (burn (token-id uint))
  (begin
    (asserts! (is-eq (some tx-sender) (nft-get-owner? simple-nft token-id)) err-not-token-owner)
    (nft-burn? simple-nft token-id tx-sender)
  )
)

;; Set base URI (owner only)
(define-public (set-base-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender contract-owner) err-owner-only)
    (var-set base-uri new-uri)
    (ok true)
  )
)

;; Get base URI
(define-read-only (get-base-uri)
  (ok (var-get base-uri))
)

```
