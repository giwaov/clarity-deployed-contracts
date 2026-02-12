---
title: "Trait mynft"
draft: true
---
```
;; title: my-nft-collection
;; summary: SIP-009 compliant NFT with specific IPFS metadata

;; Traits: Use the official SIP-009 trait address for Mainnet
;; For Testnet, use: 'ST1NXBK3K5YYMD6FD41MVNP3JS1GABZ8TRVX023PT.nft-trait.nft-trait
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; Constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u401))

;; Define the NFT Collection
(define-non-fungible-token My-NFT-Collection uint)

;; Data Vars
(define-data-var last-token-id uint u0)

;; Your specific Metadata CID
;; Using the ipfs:// protocol is the standard for OpenSea compatibility
(define-data-var base-uri (string-ascii 256) "ipfs://bafkreig4calfekw6cbrjmjdaxpyghec3oz7jcmxteq6lnp26hpjkat4twe")

;; Public Functions

;; 1. Mint function: Only you can mint
(define-public (mint (recipient principal))
  (let
    (
      (token-id (+ (var-get last-token-id) u1))
    )
    (begin
      (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
      ;; Mint the NFT to the recipient
      (try! (nft-mint? My-NFT-Collection token-id recipient))
      ;; Update the ID counter
      (var-set last-token-id token-id)
      (ok token-id)
    )
  )
)

;; 2. SIP-009: Transfer function
(define-public (transfer (id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (nft-transfer? My-NFT-Collection id sender recipient)
  )
)

;; 3. Admin: Update metadata if needed (e.g., if you change your IPFS folder)
(define-public (set-base-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set base-uri new-uri))
  )
)

;; Read-Only Functions

;; SIP-009: Get the link for token metadata
(define-read-only (get-token-uri (id uint))
  (ok (some (var-get base-uri)))
)

;; SIP-009: Get the last minted token ID
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

;; SIP-009: Get the owner of a specific token
(define-read-only (get-owner (id uint))
  (ok (nft-get-owner? My-NFT-Collection id))
)

```
