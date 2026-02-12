---
title: "Trait stacksmint-nft"
draft: true
---
```
;; StacksMint NFT Contract
;; SIP-009 Compliant NFT with Creator Fees
;; Creator Fee: 0.01 STX per mint

;; Use local SIP-009 trait for development
;; For mainnet, replace with: (impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)
(use-trait nft-trait .sip009-nft-trait.nft-trait)
(impl-trait .sip009-nft-trait.nft-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-NOT-TOKEN-OWNER (err u103))
(define-constant ERR-INVALID-TOKEN (err u104))
(define-constant ERR-LISTING-NOT-FOUND (err u105))
(define-constant ERR-WRONG-PRICE (err u106))
(define-constant ERR-TRANSFER-FAILED (err u107))
(define-constant ERR-MINT-FAILED (err u108))
(define-constant CREATOR-FEE u10000) ;; 0.01 STX in microSTX

;; Define NFT
(define-non-fungible-token stacksmint-nft uint)

;; Data Variables
(define-data-var last-token-id uint u0)
(define-data-var base-uri (string-ascii 256) "https://stacksmint.io/metadata/")

;; Data Maps
(define-map token-uris uint (string-ascii 256))
(define-map token-collection uint uint) ;; token-id -> collection-id

;; SIP-009 Functions

;; Get last token ID
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

;; Get token URI
(define-read-only (get-token-uri (token-id uint))
  (ok (map-get? token-uris token-id))
)

;; Get token owner
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? stacksmint-nft token-id))
)

;; Transfer token
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-some (nft-get-owner? stacksmint-nft token-id)) ERR-INVALID-TOKEN)
    (nft-transfer? stacksmint-nft token-id sender recipient)
  )
)

;; Read-only functions

;; Get creator fee
(define-read-only (get-creator-fee)
  CREATOR-FEE
)

;; Get base URI
(define-read-only (get-base-uri)
  (var-get base-uri)
)

;; Get token collection
(define-read-only (get-token-collection (token-id uint))
  (map-get? token-collection token-id)
)

;; Check if token exists
(define-read-only (token-exists (token-id uint))
  (is-some (nft-get-owner? stacksmint-nft token-id))
)

;; Public functions

;; Mint new NFT with creator fee
(define-public (mint (uri (string-ascii 256)))
  (let
    (
      (token-id (+ (var-get last-token-id) u1))
    )
    ;; Pay creator fee
    (try! (stx-transfer? CREATOR-FEE tx-sender CONTRACT-OWNER))
    ;; Mint NFT
    (try! (nft-mint? stacksmint-nft token-id tx-sender))
    ;; Set token URI
    (map-set token-uris token-id uri)
    ;; Update last token ID
    (var-set last-token-id token-id)
    (ok token-id)
  )
)

;; Mint NFT to collection
(define-public (mint-to-collection (uri (string-ascii 256)) (collection-id uint))
  (let
    (
      (token-id (+ (var-get last-token-id) u1))
    )
    ;; Pay creator fee
    (try! (stx-transfer? CREATOR-FEE tx-sender CONTRACT-OWNER))
    ;; Mint NFT
    (try! (nft-mint? stacksmint-nft token-id tx-sender))
    ;; Set token URI
    (map-set token-uris token-id uri)
    ;; Set collection
    (map-set token-collection token-id collection-id)
    ;; Update last token ID
    (var-set last-token-id token-id)
    (ok token-id)
  )
)

;; Burn NFT (owner only)
(define-public (burn (token-id uint))
  (begin
    (asserts! (is-eq (some tx-sender) (nft-get-owner? stacksmint-nft token-id)) ERR-NOT-TOKEN-OWNER)
    (nft-burn? stacksmint-nft token-id tx-sender)
  )
)

;; Update base URI (contract owner only)
(define-public (set-base-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (var-set base-uri new-uri)
    (ok true)
  )
)

;; Update token URI (token owner only)
(define-public (set-token-uri (token-id uint) (uri (string-ascii 256)))
  (begin
    (asserts! (is-eq (some tx-sender) (nft-get-owner? stacksmint-nft token-id)) ERR-NOT-TOKEN-OWNER)
    (map-set token-uris token-id uri)
    (ok true)
  )
)

```
