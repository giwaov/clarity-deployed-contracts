---
title: "Trait nftminting"
draft: true
---
```
;; SPDX-License-Identifier: MIT
;; SIP-009 NFT Minting Contract

;; --- TRAITS ---
;; Implements the standard NFT trait for compatibility with marketplaces/wallets
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; --- CONSTANTS ---
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-METADATA-FROZEN (err u102))

;; --- DATA ---
(define-non-fungible-token MyCollection uint)
(define-data-var last-token-id uint u0)
(define-data-var base-uri (string-ascii 256) "https://api.example.com/metadata/")

;; --- PUBLIC FUNCTIONS ---

;; Users call this to mint a new NFT
(define-public (mint)
  (let (
    (new-id (+ (var-get last-token-id) u1))
  )
    (begin
      ;; Mints the NFT to the tx-sender (the user interacting)
      (try! (nft-mint? MyCollection new-id tx-sender))
      ;; Updates the total supply counter
      (var-set last-token-id new-id)
      (ok new-id)
    )
  )
)

;; Standard transfer function required by SIP-009
(define-public (transfer (id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (nft-transfer? MyCollection id sender recipient)
  )
)

;; --- READ-ONLY FUNCTIONS (SIP-009 Required) ---

(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

(define-read-only (get-token-uri (id uint))
  (ok (some (var-get base-uri)))
)

(define-read-only (get-owner (id uint))
  (ok (nft-get-owner? MyCollection id))
)

;; --- ADMIN FUNCTIONS ---

;; Allows the owner to change the metadata URL if needed
(define-public (set-base-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set base-uri new-uri))
  )
)

```
