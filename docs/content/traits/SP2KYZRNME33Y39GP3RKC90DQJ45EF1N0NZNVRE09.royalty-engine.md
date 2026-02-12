---
title: "Trait royalty-engine"
draft: true
---
```
;; Gaga Finance Royalty Engine
;; Manages royalty configurations and calculates payouts for NFT sales
;; Fully independent and reusable across multiple marketplaces

;; ============================================
;; CONSTANTS - Error Codes
;; ============================================
(define-constant ERR-NOT-AUTHORIZED (err u300))
(define-constant ERR-NOT-FOUND (err u301))
(define-constant ERR-ALREADY-EXISTS (err u302))
(define-constant ERR-INVALID-PERCENTAGE (err u303))
(define-constant ERR-INVALID-RECIPIENT (err u304))
(define-constant ERR-CONTRACT-PAUSED (err u305))
(define-constant ERR-ROYALTY-TOO-HIGH (err u306))

;; ============================================
;; CONFIGURATION
;; ============================================
(define-constant CONTRACT-OWNER tx-sender)

;; Maximum royalty: 25% (2500 basis points)
(define-constant MAX-ROYALTY-BPS u2500)

;; Basis points denominator
(define-constant BPS-DENOMINATOR u10000)

;; ============================================
;; DATA VARIABLES
;; ============================================
(define-data-var is-paused bool false)

;; ============================================
;; DATA MAPS
;; ============================================

;; Royalty configuration per collection
;; nft-contract -> { recipient, royalty-bps, admin }
(define-map collection-royalties 
  principal 
  { 
    recipient: principal,
    royalty-bps: uint,
    admin: principal
  }
)

;; Secondary recipients for split royalties (optional)
(define-map secondary-recipients
  { nft-contract: principal, index: uint }
  { recipient: principal, share-bps: uint }
)

;; Number of secondary recipients per collection
(define-map secondary-recipient-count principal uint)

;; ============================================
;; AUTHORIZATION
;; ============================================

(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-collection-admin (nft-contract principal))
  (match (map-get? collection-royalties nft-contract)
    config (or 
      (is-eq tx-sender (get admin config))
      (is-contract-owner)
    )
    (is-contract-owner)
  )
)

(define-private (assert-not-paused)
  (ok (asserts! (not (var-get is-paused)) ERR-CONTRACT-PAUSED))
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

;; Get royalty configuration for a collection
(define-read-only (get-royalty-info (nft-contract principal))
  (ok (map-get? collection-royalties nft-contract))
)

;; Get royalty percentage in basis points
(define-read-only (get-royalty-bps (nft-contract principal))
  (ok (default-to u0 
    (match (map-get? collection-royalties nft-contract)
      config (some (get royalty-bps config))
      none
    )
  ))
)

;; Get royalty recipient
(define-read-only (get-royalty-recipient (nft-contract principal))
  (ok (match (map-get? collection-royalties nft-contract)
    config (some (get recipient config))
    none
  ))
)

;; Calculate royalty amount for a sale
(define-read-only (calculate-royalty (nft-contract principal) (sale-price uint))
  (let (
    (royalty-bps (default-to u0 
      (match (map-get? collection-royalties nft-contract)
        config (some (get royalty-bps config))
        none
      )
    ))
  )
    (ok (/ (* sale-price royalty-bps) BPS-DENOMINATOR))
  )
)

;; Get full payout breakdown for a sale
;; Returns: { royalty-amount, royalty-recipient, seller-amount }
(define-read-only (get-payout-breakdown (nft-contract principal) (sale-price uint) (protocol-fee-bps uint))
  (let (
    (royalty-bps (default-to u0 
      (match (map-get? collection-royalties nft-contract)
        config (some (get royalty-bps config))
        none
      )
    ))
    (royalty-amount (/ (* sale-price royalty-bps) BPS-DENOMINATOR))
    (protocol-fee (/ (* sale-price protocol-fee-bps) BPS-DENOMINATOR))
    (seller-amount (- (- sale-price royalty-amount) protocol-fee))
    (recipient (match (map-get? collection-royalties nft-contract)
      config (get recipient config)
      CONTRACT-OWNER ;; fallback
    ))
  )
    (ok {
      royalty-amount: royalty-amount,
      royalty-recipient: recipient,
      protocol-fee: protocol-fee,
      seller-amount: seller-amount
    })
  )
)

;; Check if collection has royalty configured
(define-read-only (has-royalty (nft-contract principal))
  (is-some (map-get? collection-royalties nft-contract))
)

;; Get maximum allowed royalty
(define-read-only (get-max-royalty-bps)
  (ok MAX-ROYALTY-BPS)
)

;; Check pause status
(define-read-only (is-contract-paused)
  (ok (var-get is-paused))
)

;; Get secondary recipient count
(define-read-only (get-secondary-recipient-count (nft-contract principal))
  (ok (default-to u0 (map-get? secondary-recipient-count nft-contract)))
)

;; Get secondary recipient at index
(define-read-only (get-secondary-recipient (nft-contract principal) (index uint))
  (ok (map-get? secondary-recipients { nft-contract: nft-contract, index: index }))
)

;; ============================================
;; PUBLIC FUNCTIONS - ROYALTY CONFIGURATION
;; ============================================

;; Register royalty for a new collection
(define-public (register-collection (nft-contract principal) (recipient principal) (royalty-bps uint))
  (begin
    (try! (assert-not-paused))
    
    ;; Only contract owner can register new collections
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    
    ;; Validate royalty is within limits
    (asserts! (<= royalty-bps MAX-ROYALTY-BPS) ERR-ROYALTY-TOO-HIGH)
    
    ;; Check collection not already registered
    (asserts! (not (has-royalty nft-contract)) ERR-ALREADY-EXISTS)
    
    ;; Set royalty configuration
    (map-set collection-royalties nft-contract {
      recipient: recipient,
      royalty-bps: royalty-bps,
      admin: tx-sender
    })
    
    (print { 
      event: "collection-registered",
      nft-contract: nft-contract,
      recipient: recipient,
      royalty-bps: royalty-bps
    })
    
    (ok true)
  )
)

;; Update royalty percentage (collection admin only)
(define-public (update-royalty-bps (nft-contract principal) (new-royalty-bps uint))
  (begin
    (try! (assert-not-paused))
    
    ;; Check caller is collection admin
    (asserts! (is-collection-admin nft-contract) ERR-NOT-AUTHORIZED)
    
    ;; Validate new royalty
    (asserts! (<= new-royalty-bps MAX-ROYALTY-BPS) ERR-ROYALTY-TOO-HIGH)
    
    ;; Get existing config
    (let (
      (config (unwrap! (map-get? collection-royalties nft-contract) ERR-NOT-FOUND))
    )
      ;; Update only the royalty
      (map-set collection-royalties nft-contract 
        (merge config { royalty-bps: new-royalty-bps })
      )
      
      (print { 
        event: "royalty-updated",
        nft-contract: nft-contract,
        old-royalty-bps: (get royalty-bps config),
        new-royalty-bps: new-royalty-bps
      })
      
      (ok true)
    )
  )
)

;; Update royalty recipient (collection admin only)
(define-public (update-royalty-recipient (nft-contract principal) (new-recipient principal))
  (begin
    (try! (assert-not-paused))
    
    (asserts! (is-collection-admin nft-contract) ERR-NOT-AUTHORIZED)
    
    (let (
      (config (unwrap! (map-get? collection-royalties nft-contract) ERR-NOT-FOUND))
    )
      (map-set collection-royalties nft-contract 
        (merge config { recipient: new-recipient })
      )
      
      (print { 
        event: "recipient-updated",
        nft-contract: nft-contract,
        old-recipient: (get recipient config),
        new-recipient: new-recipient
      })
      
      (ok true)
    )
  )
)

;; Transfer collection admin (current admin only)
(define-public (transfer-admin (nft-contract principal) (new-admin principal))
  (begin
    (try! (assert-not-paused))
    
    (asserts! (is-collection-admin nft-contract) ERR-NOT-AUTHORIZED)
    
    (let (
      (config (unwrap! (map-get? collection-royalties nft-contract) ERR-NOT-FOUND))
    )
      (map-set collection-royalties nft-contract 
        (merge config { admin: new-admin })
      )
      
      (print { 
        event: "admin-transferred",
        nft-contract: nft-contract,
        old-admin: (get admin config),
        new-admin: new-admin
      })
      
      (ok true)
    )
  )
)

;; ============================================
;; SECONDARY RECIPIENTS (SPLIT ROYALTIES)
;; ============================================

;; Add secondary recipient for split royalties
(define-public (add-secondary-recipient (nft-contract principal) (recipient principal) (share-bps uint))
  (begin
    (try! (assert-not-paused))
    (asserts! (is-collection-admin nft-contract) ERR-NOT-AUTHORIZED)
    
    (let (
      (current-count (default-to u0 (map-get? secondary-recipient-count nft-contract)))
      (new-index current-count)
    )
      ;; Max 5 secondary recipients
      (asserts! (< current-count u5) ERR-INVALID-PERCENTAGE)
      
      ;; Add recipient
      (map-set secondary-recipients 
        { nft-contract: nft-contract, index: new-index }
        { recipient: recipient, share-bps: share-bps }
      )
      
      ;; Increment count
      (map-set secondary-recipient-count nft-contract (+ current-count u1))
      
      (print { 
        event: "secondary-recipient-added",
        nft-contract: nft-contract,
        index: new-index,
        recipient: recipient,
        share-bps: share-bps
      })
      
      (ok true)
    )
  )
)

;; ============================================
;; ADMIN FUNCTIONS
;; ============================================

;; Pause contract
(define-public (set-paused (paused bool))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set is-paused paused)
    (print { event: "pause-status-changed", paused: paused })
    (ok true)
  )
)

;; Remove collection royalty configuration (owner only)
(define-public (remove-collection (nft-contract principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    
    (map-delete collection-royalties nft-contract)
    
    (print { 
      event: "collection-removed",
      nft-contract: nft-contract
    })
    
    (ok true)
  )
)


```
