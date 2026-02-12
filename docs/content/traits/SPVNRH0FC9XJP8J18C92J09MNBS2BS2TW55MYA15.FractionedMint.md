---
title: "Trait FractionedMint"
draft: true
---
```
;; title: FractionedMint
;; version:
;; summary:
;; description:

;; title: STX-FractionedNFT
;; version: 1.0.0
;; summary: Fractionalized Bitcoin NFT contract for turning rare Bitcoin Ordinals into fractional NFTs on Stacks
;; description: This contract allows users to deposit Bitcoin Ordinals and mint fractional tokens representing ownership


;; token definitions
(define-non-fungible-token fractionalized-ordinal uint)
(define-fungible-token fraction-token)

;; constants
(define-constant CONTRACT-OWNER tx-sender)
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-EXISTS (err u102))
(define-constant ERR-INSUFFICIENT-BALANCE (err u103))
(define-constant ERR-INVALID-AMOUNT (err u104))
(define-constant ERR-NOT-OWNER (err u105))
(define-constant ERR-ORDINAL-NOT-VERIFIED (err u106))
(define-constant ERR-ALREADY-FRACTIONALIZED (err u107))
(define-constant ERR-NOT-FRACTIONALIZED (err u108))
(define-constant ERR-INSUFFICIENT-FRACTIONS (err u109))

;; data vars
(define-data-var next-nft-id uint u1)
(define-data-var contract-fee uint u250) ;; 2.5% fee in basis points

;; data maps
(define-map ordinal-metadata
  { nft-id: uint }
  {
    ordinal-id: (string-ascii 64),
    inscription-number: uint,
    creator: principal,
    total-fractions: uint,
    fractions-outstanding: uint,
    metadata-uri: (string-utf8 256),
    is-fractionalized: bool,
    created-at: uint
  }
)

(define-map ordinal-verification
  { ordinal-id: (string-ascii 64) }
  {
    bitcoin-tx-id: (string-ascii 64),
    output-index: uint,
    verified: bool,
    verifier: principal,
    verified-at: uint
  }
)

(define-map fraction-balances
  { owner: principal, nft-id: uint }
  { balance: uint }
)

(define-map fraction-allowances
  { owner: principal, spender: principal, nft-id: uint }
  { allowance: uint }
)

(define-public (verify-ordinal (ordinal-id (string-ascii 64)))
  (let
    (
      (verification-data (unwrap! (map-get? ordinal-verification { ordinal-id: ordinal-id }) ERR-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender CONTRACT-OWNER) (is-eq tx-sender (get verifier verification-data))) ERR-NOT-AUTHORIZED)
    
    (map-set ordinal-verification
      { ordinal-id: ordinal-id }
      (merge verification-data { verified: true, verified-at: stacks-block-height })
    )
    (ok true)
  )
)

(define-public (fractionalize-ordinal 
  (nft-id uint)
  (total-fractions uint)
)
  (let
    (
      (metadata (unwrap! (map-get? ordinal-metadata { nft-id: nft-id }) ERR-NOT-FOUND))
      (owner (unwrap! (nft-get-owner? fractionalized-ordinal nft-id) ERR-NOT-FOUND))
      (verification (unwrap! (map-get? ordinal-verification { ordinal-id: (get ordinal-id metadata) }) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender owner) ERR-NOT-OWNER)
    (asserts! (get verified verification) ERR-ORDINAL-NOT-VERIFIED)
    (asserts! (not (get is-fractionalized metadata)) ERR-ALREADY-FRACTIONALIZED)
    (asserts! (> total-fractions u0) ERR-INVALID-AMOUNT)
    
    (try! (ft-mint? fraction-token total-fractions tx-sender))
    
    (map-set ordinal-metadata
      { nft-id: nft-id }
      (merge metadata { 
        total-fractions: total-fractions,
        fractions-outstanding: total-fractions,
        is-fractionalized: true
      })
    )
    
    (map-set fraction-balances
      { owner: tx-sender, nft-id: nft-id }
      { balance: total-fractions }
    )
    
    (ok total-fractions)
  )
)

(define-public (transfer-fractions
  (nft-id uint)
  (amount uint)
  (recipient principal)
)
  (let
    (
      (sender-balance (default-to u0 (get balance (map-get? fraction-balances { owner: tx-sender, nft-id: nft-id }))))
      (recipient-balance (default-to u0 (get balance (map-get? fraction-balances { owner: recipient, nft-id: nft-id }))))
      (metadata (unwrap! (map-get? ordinal-metadata { nft-id: nft-id }) ERR-NOT-FOUND))
    )
    (asserts! (get is-fractionalized metadata) ERR-NOT-FRACTIONALIZED)
    (asserts! (>= sender-balance amount) ERR-INSUFFICIENT-BALANCE)
    (asserts! (> amount u0) ERR-INVALID-AMOUNT)
    
    (map-set fraction-balances
      { owner: tx-sender, nft-id: nft-id }
      { balance: (- sender-balance amount) }
    )
    
    (map-set fraction-balances
      { owner: recipient, nft-id: nft-id }
      { balance: (+ recipient-balance amount) }
    )
    
    (ok true)
  )
)


(define-read-only (get-last-token-id)
  (- (var-get next-nft-id) u1)
)

(define-read-only (get-token-uri (nft-id uint))
  (ok (some (get metadata-uri (unwrap! (map-get? ordinal-metadata { nft-id: nft-id }) ERR-NOT-FOUND))))
)

(define-read-only (get-owner (nft-id uint))
  (ok (nft-get-owner? fractionalized-ordinal nft-id))
)

(define-read-only (get-ordinal-metadata (nft-id uint))
  (map-get? ordinal-metadata { nft-id: nft-id })
)

(define-read-only (get-ordinal-verification (ordinal-id (string-ascii 64)))
  (map-get? ordinal-verification { ordinal-id: ordinal-id })
)

(define-read-only (get-fraction-balance (owner principal) (nft-id uint))
  (default-to u0 (get balance (map-get? fraction-balances { owner: owner, nft-id: nft-id })))
)

(define-read-only (get-fraction-total-supply (nft-id uint))
  (match (map-get? ordinal-metadata { nft-id: nft-id })
    metadata (get total-fractions metadata)
    u0
  )
)

(define-read-only (is-fractionalized (nft-id uint))
  (match (map-get? ordinal-metadata { nft-id: nft-id })
    metadata (get is-fractionalized metadata)
    false
  )
)

;; private functions

(define-private (is-owner-or-approved (nft-id uint) (user principal))
  (match (nft-get-owner? fractionalized-ordinal nft-id)
    owner (is-eq user owner)
    false
  )
)

;; SIP-009 NFT trait implementation
(define-public (transfer (nft-id uint) (sender principal) (recipient principal))
  (begin
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (asserts! (is-owner-or-approved nft-id sender) ERR-NOT-AUTHORIZED)
    (nft-transfer? fractionalized-ordinal nft-id sender recipient)
  )
)


```
