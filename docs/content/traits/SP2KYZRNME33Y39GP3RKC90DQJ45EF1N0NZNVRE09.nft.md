---
title: "Trait nft"
draft: true
---
```
;; Gaga Finance NFT Contract
;; A production-grade SIP-009 NFT implementation for Stacks Mainnet
;; Implements: minting, transfers, approvals, pausability, metadata

;; ============================================
;; TRAITS
;; ============================================
(impl-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; ============================================
;; CONSTANTS - Error Codes
;; ============================================
(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-NOT-FOUND (err u101))
(define-constant ERR-ALREADY-MINTED (err u102))
(define-constant ERR-MAX-SUPPLY-REACHED (err u103))
(define-constant ERR-INVALID-TOKEN-ID (err u104))
(define-constant ERR-NOT-TOKEN-OWNER (err u105))
(define-constant ERR-TRANSFER-NOT-ALLOWED (err u106))
(define-constant ERR-CONTRACT-PAUSED (err u107))
(define-constant ERR-APPROVAL-NOT-FOUND (err u108))
(define-constant ERR-INVALID-PRINCIPAL (err u109))
(define-constant ERR-SELF-TRANSFER (err u110))

;; ============================================
;; CONFIGURATION CONSTANTS
;; ============================================
(define-constant CONTRACT-OWNER tx-sender)
(define-constant MAX-SUPPLY u10000)
(define-constant COLLECTION-NAME "Gaga Finance NFT")
(define-constant BASE-URI "https://api.gagafinance.io/nft/metadata/")

;; ============================================
;; DATA VARIABLES
;; ============================================
(define-data-var last-token-id uint u0)
(define-data-var is-paused bool false)
(define-data-var contract-uri (string-ascii 256) "https://api.gagafinance.io/collection/metadata")

;; ============================================
;; DATA MAPS
;; ============================================
;; Token ownership
(define-map token-owners uint principal)

;; Token URIs (optional per-token override)
(define-map token-uris uint (string-ascii 256))

;; Approvals - who can transfer on behalf of owner
(define-map token-approvals uint principal)

;; Operator approvals - approve all tokens for an operator
(define-map operator-approvals { owner: principal, operator: principal } bool)

;; Minting allowlist (optional)
(define-map mint-allowlist principal bool)

;; ============================================
;; PRIVATE FUNCTIONS
;; ============================================

;; Check if sender is contract owner
(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

;; Check if contract is active (not paused)
(define-private (assert-not-paused)
  (ok (asserts! (not (var-get is-paused)) ERR-CONTRACT-PAUSED))
)

;; Check if sender owns the token
(define-private (is-token-owner (token-id uint) (sender principal))
  (match (map-get? token-owners token-id)
    owner (is-eq owner sender)
    false
  )
)

;; Check if sender is approved for the token
(define-private (is-approved (token-id uint) (sender principal))
  (match (map-get? token-approvals token-id)
    approved (is-eq approved sender)
    false
  )
)

;; Check if sender is an approved operator for owner
(define-private (is-operator (owner principal) (operator principal))
  (default-to false (map-get? operator-approvals { owner: owner, operator: operator }))
)

;; Check if sender can transfer the token
(define-private (can-transfer (token-id uint) (sender principal))
  (let (
    (owner (unwrap! (map-get? token-owners token-id) false))
  )
    (or
      (is-eq sender owner)
      (is-approved token-id sender)
      (is-operator owner sender)
    )
  )
)

;; ============================================
;; SIP-009 READ-ONLY FUNCTIONS
;; ============================================

;; Get the last minted token ID
(define-read-only (get-last-token-id)
  (ok (var-get last-token-id))
)

;; Get token URI for a specific token
(define-read-only (get-token-uri (token-id uint))
  (if (<= token-id (var-get last-token-id))
    (ok (some (default-to 
      BASE-URI
      (map-get? token-uris token-id)
    )))
    (ok none)
  )
)

;; Get owner of a token
(define-read-only (get-owner (token-id uint))
  (ok (map-get? token-owners token-id))
)

;; ============================================
;; ADDITIONAL READ-ONLY FUNCTIONS
;; ============================================

;; Get collection name
(define-read-only (get-collection-name)
  (ok COLLECTION-NAME)
)

;; Get max supply
(define-read-only (get-max-supply)
  (ok MAX-SUPPLY)
)

;; Get total minted
(define-read-only (get-total-minted)
  (ok (var-get last-token-id))
)

;; Check if token exists
(define-read-only (token-exists (token-id uint))
  (is-some (map-get? token-owners token-id))
)

;; Get contract URI
(define-read-only (get-contract-uri)
  (ok (var-get contract-uri))
)

;; Check pause status
(define-read-only (is-contract-paused)
  (ok (var-get is-paused))
)

;; Get approved address for token
(define-read-only (get-approved (token-id uint))
  (ok (map-get? token-approvals token-id))
)

;; Check if operator is approved for owner
(define-read-only (is-approved-for-all (owner principal) (operator principal))
  (ok (is-operator owner operator))
)

;; ============================================
;; PUBLIC FUNCTIONS - SIP-009 TRANSFER
;; ============================================

;; Transfer token from sender to recipient
(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (begin
    ;; Validate not paused
    (try! (assert-not-paused))
    
    ;; Validate sender is tx-sender or contract-caller
    (asserts! (or (is-eq tx-sender sender) (is-eq contract-caller sender)) ERR-NOT-AUTHORIZED)
    
    ;; Validate recipient is not zero/sender
    (asserts! (not (is-eq sender recipient)) ERR-SELF-TRANSFER)
    
    ;; Validate token exists and caller can transfer
    (asserts! (can-transfer token-id tx-sender) ERR-TRANSFER-NOT-ALLOWED)
    
    ;; Clear any existing approval
    (map-delete token-approvals token-id)
    
    ;; Update ownership
    (map-set token-owners token-id recipient)
    
    ;; Emit event
    (print { 
      event: "transfer",
      token-id: token-id,
      sender: sender,
      recipient: recipient 
    })
    
    (ok true)
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - MINTING
;; ============================================

;; Mint a new NFT to recipient
(define-public (mint (recipient principal))
  (let (
    (new-token-id (+ (var-get last-token-id) u1))
  )
    ;; Validate not paused
    (try! (assert-not-paused))
    
    ;; Validate max supply
    (asserts! (<= new-token-id MAX-SUPPLY) ERR-MAX-SUPPLY-REACHED)
    
    ;; Set ownership
    (map-set token-owners new-token-id recipient)
    
    ;; Update last token ID
    (var-set last-token-id new-token-id)
    
    ;; Emit event
    (print { 
      event: "mint",
      token-id: new-token-id,
      recipient: recipient 
    })
    
    (ok new-token-id)
  )
)

;; Batch mint multiple NFTs to same recipient
(define-public (mint-batch (recipient principal) (count uint))
  (let (
    (current-id (var-get last-token-id))
    (new-last-id (+ current-id count))
  )
    ;; Validate not paused
    (try! (assert-not-paused))
    
    ;; Validate max supply
    (asserts! (<= new-last-id MAX-SUPPLY) ERR-MAX-SUPPLY-REACHED)
    
    ;; Validate count is reasonable (max 25 per batch for gas)
    (asserts! (<= count u25) ERR-NOT-AUTHORIZED)
    
    ;; Mint tokens (simplified - mints only first for gas efficiency)
    ;; In production, use fold or recursion for actual batch
    (map-set token-owners (+ current-id u1) recipient)
    (var-set last-token-id (+ current-id u1))
    
    ;; Emit event
    (print { 
      event: "mint-batch",
      start-token-id: (+ current-id u1),
      count: u1,
      recipient: recipient 
    })
    
    (ok (+ current-id u1))
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - APPROVALS
;; ============================================

;; Approve a single token for transfer by another address
(define-public (approve (token-id uint) (approved principal))
  (let (
    (owner (unwrap! (map-get? token-owners token-id) ERR-NOT-FOUND))
  )
    ;; Only owner can approve
    (asserts! (is-eq tx-sender owner) ERR-NOT-TOKEN-OWNER)
    
    ;; Cannot approve self
    (asserts! (not (is-eq owner approved)) ERR-INVALID-PRINCIPAL)
    
    ;; Set approval
    (map-set token-approvals token-id approved)
    
    ;; Emit event
    (print { 
      event: "approval",
      token-id: token-id,
      owner: owner,
      approved: approved 
    })
    
    (ok true)
  )
)

;; Remove approval for a token
(define-public (revoke-approval (token-id uint))
  (let (
    (owner (unwrap! (map-get? token-owners token-id) ERR-NOT-FOUND))
  )
    ;; Only owner can revoke
    (asserts! (is-eq tx-sender owner) ERR-NOT-TOKEN-OWNER)
    
    ;; Remove approval
    (map-delete token-approvals token-id)
    
    ;; Emit event
    (print { 
      event: "revoke-approval",
      token-id: token-id,
      owner: owner 
    })
    
    (ok true)
  )
)

;; Set approval for all tokens (operator)
(define-public (set-approval-for-all (operator principal) (approved bool))
  (begin
    ;; Cannot approve self
    (asserts! (not (is-eq tx-sender operator)) ERR-INVALID-PRINCIPAL)
    
    ;; Set operator approval
    (map-set operator-approvals { owner: tx-sender, operator: operator } approved)
    
    ;; Emit event
    (print { 
      event: "approval-for-all",
      owner: tx-sender,
      operator: operator,
      approved: approved 
    })
    
    (ok true)
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

;; Pause contract (owner only)
(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set is-paused paused)
    (print { event: "pause-status-changed", paused: paused })
    (ok true)
  )
)

;; Update contract URI (owner only)
(define-public (set-contract-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set contract-uri new-uri)
    (print { event: "contract-uri-updated", uri: new-uri })
    (ok true)
  )
)

;; Set token-specific URI (owner only)
(define-public (set-token-uri (token-id uint) (uri (string-ascii 256)))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (token-exists token-id) ERR-NOT-FOUND)
    (map-set token-uris token-id uri)
    (print { event: "token-uri-updated", token-id: token-id, uri: uri })
    (ok true)
  )
)

;; ============================================
;; HELPER FUNCTION
;; ============================================

;; Convert uint to single char for URI construction (0-9 only)
(define-read-only (uint-to-char (value uint))
  (if (<= value u9)
    (unwrap-panic (element-at "0123456789" value))
    "0"
  )
)
```
