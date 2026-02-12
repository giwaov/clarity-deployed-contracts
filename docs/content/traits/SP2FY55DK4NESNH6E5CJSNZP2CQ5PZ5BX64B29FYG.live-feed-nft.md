---
title: "Trait live-feed-nft"
draft: true
---
```
;; Live Feed Test NFT
;; A simple SIP-009 NFT contract for testing the Stacks NFT Live Feed
;; 
;; Features:
;; - Public minting (anyone can mint)
;; - Standard transfers
;; - Burn functionality
;; - Perfect for generating test events for the live feed

;; ============================================
;; TRAITS
;; ============================================

(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; ============================================
;; CONSTANTS
;; ============================================

(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-OWNER (err u100))
(define-constant ERR-NOT-TOKEN-OWNER (err u101))
(define-constant ERR-TOKEN-NOT-FOUND (err u102))
(define-constant ERR-ALREADY-MINTED (err u103))

;; ============================================
;; DATA VARIABLES
;; ============================================

(define-data-var last-token-id uint u0)
(define-data-var base-uri (string-ascii 256) "https://api.stacksnftlivefeed.com/metadata/")

;; ============================================
;; DATA MAPS
;; ============================================

(define-map token-owners uint principal)
(define-map token-uris uint (string-ascii 256))

;; ============================================
;; NFT DEFINITION
;; ============================================

(define-non-fungible-token live-feed-nft uint)

;; ============================================
;; SIP-009 FUNCTIONS
;; ============================================

;; Get the last minted token ID
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

;; Get the token URI for a specific token
(define-read-only (get-token-uri (token-id uint))
  (ok (some (var-get base-uri)))
)

;; Get the owner of a specific token
(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? live-feed-nft token-id))
)

;; Transfer a token
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    ;; Check that sender owns the token
    (asserts! (is-eq tx-sender sender) ERR-NOT-TOKEN-OWNER)
    (asserts! (is-some (nft-get-owner? live-feed-nft token-id)) ERR-TOKEN-NOT-FOUND)
    (asserts! (is-eq (some sender) (nft-get-owner? live-feed-nft token-id)) ERR-NOT-TOKEN-OWNER)
    
    ;; Transfer the NFT
    (try! (nft-transfer? live-feed-nft token-id sender recipient))
    
    ;; Update owner map
    (map-set token-owners token-id recipient)
    
    (print { 
      type: "transfer", 
      token-id: token-id, 
      from: sender, 
      to: recipient 
    })
    
    (ok true)
  )
)

;; ============================================
;; PUBLIC MINTING
;; ============================================

;; Anyone can mint (for testing purposes)
(define-public (mint)
  (let
    (
      (token-id (+ (var-get last-token-id) u1))
    )
    ;; Mint the NFT
    (try! (nft-mint? live-feed-nft token-id tx-sender))
    
    ;; Update state
    (var-set last-token-id token-id)
    (map-set token-owners token-id tx-sender)
    
    (print { 
      type: "mint", 
      token-id: token-id, 
      recipient: tx-sender 
    })
    
    (ok token-id)
  )
)

;; Mint multiple NFTs at once
(define-public (mint-many (count uint))
  (let
    (
      (start-id (+ (var-get last-token-id) u1))
    )
    (asserts! (<= count u10) (err u104)) ;; Max 10 per call
    
    (fold mint-iter 
      (list u1 u2 u3 u4 u5 u6 u7 u8 u9 u10) 
      (ok { minted: u0, target: count })
    )
  )
)

(define-private (mint-iter (i uint) (state (response { minted: uint, target: uint } uint)))
  (match state
    ok-state
      (if (< (get minted ok-state) (get target ok-state))
        (match (mint)
          success (ok { minted: (+ (get minted ok-state) u1), target: (get target ok-state) })
          error state
        )
        state
      )
    err-state state
  )
)

;; ============================================
;; BURN
;; ============================================

;; Burn an NFT (only owner can burn)
(define-public (burn (token-id uint))
  (begin
    ;; Check ownership
    (asserts! (is-some (nft-get-owner? live-feed-nft token-id)) ERR-TOKEN-NOT-FOUND)
    (asserts! (is-eq (some tx-sender) (nft-get-owner? live-feed-nft token-id)) ERR-NOT-TOKEN-OWNER)
    
    ;; Burn the NFT
    (try! (nft-burn? live-feed-nft token-id tx-sender))
    
    ;; Clean up
    (map-delete token-owners token-id)
    
    (print { 
      type: "burn", 
      token-id: token-id, 
      owner: tx-sender 
    })
    
    (ok true)
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

;; Update base URI (admin only)
(define-public (set-base-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-OWNER)
    (var-set base-uri new-uri)
    (ok true)
  )
)

;; ============================================
;; READ-ONLY HELPERS
;; ============================================

;; Get total supply
(define-read-only (get-total-supply)
  (var-get last-token-id)
)

;; Check if address owns a specific token
(define-read-only (is-owner (token-id uint) (address principal))
  (is-eq (some address) (nft-get-owner? live-feed-nft token-id))
)

;; Get contract info
(define-read-only (get-contract-info)
  {
    name: "Live Feed Test NFT",
    symbol: "LFNFT",
    total-supply: (var-get last-token-id),
    base-uri: (var-get base-uri),
    owner: CONTRACT-OWNER
  }
)

```
