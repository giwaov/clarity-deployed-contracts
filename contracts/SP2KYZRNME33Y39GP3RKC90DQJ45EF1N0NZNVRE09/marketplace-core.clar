;; Gaga Finance Marketplace Core
;; Central orchestration contract for fixed-price listings
;; Coordinates with Escrow, Royalty Engine, and Auction modules

;; ============================================
;; TRAITS
;; ============================================
(use-trait nft-trait 'SP2PABAF9FTAJYNFZH93XENAJ8FVY99RRM50D2JG9.nft-trait.nft-trait)

;; ============================================
;; CONSTANTS - Error Codes
;; ============================================
(define-constant ERR-NOT-AUTHORIZED (err u500))
(define-constant ERR-NOT-FOUND (err u501))
(define-constant ERR-LISTING-EXISTS (err u502))
(define-constant ERR-LISTING-NOT-ACTIVE (err u503))
(define-constant ERR-INSUFFICIENT-FUNDS (err u504))
(define-constant ERR-TRANSFER-FAILED (err u505))
(define-constant ERR-CONTRACT-PAUSED (err u506))
(define-constant ERR-INVALID-PRICE (err u507))
(define-constant ERR-CANNOT-BUY-OWN (err u508))
(define-constant ERR-NOT-TOKEN-OWNER (err u509))
(define-constant ERR-NOT-SELLER (err u510))
(define-constant ERR-NFT-NOT-APPROVED (err u511))

;; ============================================
;; CONFIGURATION
;; ============================================
(define-constant CONTRACT-OWNER tx-sender)

;; Protocol fee: 2.5% (250 basis points)
(define-constant DEFAULT-PROTOCOL-FEE-BPS u250)

;; Basis points denominator
(define-constant BPS-DENOMINATOR u10000)

;; ============================================
;; DATA VARIABLES
;; ============================================
(define-data-var is-paused bool false)
(define-data-var next-listing-id uint u1)
(define-data-var protocol-fee-bps uint DEFAULT-PROTOCOL-FEE-BPS)
(define-data-var fee-recipient principal CONTRACT-OWNER)

;; Module references
(define-data-var escrow-contract principal CONTRACT-OWNER)
(define-data-var royalty-contract principal CONTRACT-OWNER)
(define-data-var auction-contract principal CONTRACT-OWNER)

;; Stats
(define-data-var total-listings uint u0)
(define-data-var total-sales uint u0)
(define-data-var total-volume uint u0)
(define-data-var total-fees-collected uint u0)

;; ============================================
;; DATA MAPS
;; ============================================

;; Fixed-price listings
(define-map listings uint {
  seller: principal,
  nft-contract: principal,
  token-id: uint,
  price: uint,
  created-at-block: uint,
  is-active: bool
})

;; NFT to listing ID mapping
(define-map nft-to-listing { nft-contract: principal, token-id: uint } uint)

;; Seller's active listings count
(define-map seller-listing-count principal uint)

;; ============================================
;; AUTHORIZATION
;; ============================================

(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (assert-not-paused)
  (ok (asserts! (not (var-get is-paused)) ERR-CONTRACT-PAUSED))
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

;; Get listing by ID
(define-read-only (get-listing (listing-id uint))
  (ok (map-get? listings listing-id))
)

;; Get listing ID for an NFT
(define-read-only (get-listing-by-nft (nft-contract principal) (token-id uint))
  (ok (map-get? nft-to-listing { nft-contract: nft-contract, token-id: token-id }))
)

;; Check if NFT is listed
(define-read-only (is-listed (nft-contract principal) (token-id uint))
  (match (map-get? nft-to-listing { nft-contract: nft-contract, token-id: token-id })
    listing-id (match (map-get? listings listing-id)
      listing (get is-active listing)
      false
    )
    false
  )
)

;; Get next listing ID
(define-read-only (get-next-listing-id)
  (ok (var-get next-listing-id))
)

;; Get protocol fee in basis points
(define-read-only (get-protocol-fee-bps)
  (ok (var-get protocol-fee-bps))
)

;; Get fee recipient
(define-read-only (get-fee-recipient)
  (ok (var-get fee-recipient))
)

;; Check pause status
(define-read-only (get-paused-status)
  (ok (var-get is-paused))
)

;; Get marketplace stats
(define-read-only (get-stats)
  (ok {
    total-listings: (var-get total-listings),
    total-sales: (var-get total-sales),
    total-volume: (var-get total-volume),
    total-fees: (var-get total-fees-collected)
  })
)

;; Get seller's listing count
(define-read-only (get-seller-listing-count (seller principal))
  (ok (default-to u0 (map-get? seller-listing-count seller)))
)

;; Calculate purchase costs
(define-read-only (get-purchase-breakdown (listing-id uint))
  (match (map-get? listings listing-id)
    listing (let (
      (price (get price listing))
      (protocol-fee (/ (* price (var-get protocol-fee-bps)) BPS-DENOMINATOR))
      (seller-proceeds (- price protocol-fee))
    )
      (ok {
        price: price,
        protocol-fee: protocol-fee,
        seller-proceeds: seller-proceeds
      })
    )
    ERR-NOT-FOUND
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - LISTING MANAGEMENT
;; ============================================

;; Create a fixed-price listing
(define-public (create-listing 
  (nft-contract <nft-trait>)
  (token-id uint)
  (price uint)
)
  (let (
    (listing-id (var-get next-listing-id))
    (nft-principal (contract-of nft-contract))
  )
    (try! (assert-not-paused))
    
    ;; Validate price
    (asserts! (> price u0) ERR-INVALID-PRICE)
    
    ;; Check NFT not already listed
    (asserts! (not (is-listed nft-principal token-id)) ERR-LISTING-EXISTS)
    
    ;; Verify sender owns the NFT
    (let (
      (owner-result (try! (contract-call? nft-contract get-owner token-id)))
    )
      (asserts! (is-eq owner-result (some tx-sender)) ERR-NOT-TOKEN-OWNER)
    )
    
    ;; Create listing record
    (map-set listings listing-id {
      seller: tx-sender,
      nft-contract: nft-principal,
      token-id: token-id,
      price: price,
      created-at-block: stacks-block-height,
      is-active: true
    })
    
    ;; Map NFT to listing
    (map-set nft-to-listing { nft-contract: nft-principal, token-id: token-id } listing-id)
    
    ;; Update seller count
    (map-set seller-listing-count tx-sender 
      (+ (default-to u0 (map-get? seller-listing-count tx-sender)) u1)
    )
    
    ;; Increment counters
    (var-set next-listing-id (+ listing-id u1))
    (var-set total-listings (+ (var-get total-listings) u1))
    
    (print {
      event: "listing-created",
      listing-id: listing-id,
      seller: tx-sender,
      nft-contract: nft-principal,
      token-id: token-id,
      price: price
    })
    
    (ok listing-id)
  )
)

;; Update listing price
(define-public (update-listing-price (listing-id uint) (new-price uint))
  (let (
    (listing (unwrap! (map-get? listings listing-id) ERR-NOT-FOUND))
  )
    (try! (assert-not-paused))
    
    ;; Only seller can update
    (asserts! (is-eq tx-sender (get seller listing)) ERR-NOT-SELLER)
    
    ;; Must be active
    (asserts! (get is-active listing) ERR-LISTING-NOT-ACTIVE)
    
    ;; Validate new price
    (asserts! (> new-price u0) ERR-INVALID-PRICE)
    
    ;; Update price
    (map-set listings listing-id (merge listing { price: new-price }))
    
    (print {
      event: "listing-price-updated",
      listing-id: listing-id,
      old-price: (get price listing),
      new-price: new-price
    })
    
    (ok true)
  )
)

;; Cancel a listing
(define-public (cancel-listing (listing-id uint))
  (let (
    (listing (unwrap! (map-get? listings listing-id) ERR-NOT-FOUND))
  )
    ;; Only seller can cancel
    (asserts! (is-eq tx-sender (get seller listing)) ERR-NOT-SELLER)
    
    ;; Must be active
    (asserts! (get is-active listing) ERR-LISTING-NOT-ACTIVE)
    
    ;; Deactivate listing
    (map-set listings listing-id (merge listing { is-active: false }))
    
    ;; Remove NFT mapping
    (map-delete nft-to-listing { 
      nft-contract: (get nft-contract listing), 
      token-id: (get token-id listing) 
    })
    
    ;; Decrement seller count
    (let (
      (current-count (default-to u0 (map-get? seller-listing-count tx-sender)))
    )
      (if (> current-count u0)
        (map-set seller-listing-count tx-sender (- current-count u1))
        true
      )
    )
    
    (print {
      event: "listing-cancelled",
      listing-id: listing-id,
      seller: tx-sender
    })
    
    (ok true)
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - PURCHASES
;; ============================================

;; Buy a listed NFT
(define-public (buy-listing 
  (listing-id uint)
  (nft-contract <nft-trait>)
)
  (let (
    (listing (unwrap! (map-get? listings listing-id) ERR-NOT-FOUND))
    (nft-principal (contract-of nft-contract))
  )
    (try! (assert-not-paused))
    
    ;; Validate NFT contract matches
    (asserts! (is-eq nft-principal (get nft-contract listing)) ERR-NOT-FOUND)
    
    ;; Must be active
    (asserts! (get is-active listing) ERR-LISTING-NOT-ACTIVE)
    
    ;; Cannot buy own listing
    (asserts! (not (is-eq tx-sender (get seller listing))) ERR-CANNOT-BUY-OWN)
    
    (let (
      (price (get price listing))
      (seller (get seller listing))
      (token-id (get token-id listing))
      (protocol-fee (/ (* price (var-get protocol-fee-bps)) BPS-DENOMINATOR))
      (seller-proceeds (- price protocol-fee))
    )
      ;; Transfer STX from buyer to seller
      (try! (stx-transfer? seller-proceeds tx-sender seller))
      
      ;; Transfer protocol fee to fee recipient
      (if (> protocol-fee u0)
        (try! (stx-transfer? protocol-fee tx-sender (var-get fee-recipient)))
        true
      )
      
      ;; Transfer NFT from seller to buyer
      (try! (contract-call? nft-contract transfer token-id seller tx-sender))
      
      ;; Deactivate listing
      (map-set listings listing-id (merge listing { is-active: false }))
      
      ;; Remove NFT mapping
      (map-delete nft-to-listing { nft-contract: nft-principal, token-id: token-id })
      
      ;; Update stats
      (var-set total-sales (+ (var-get total-sales) u1))
      (var-set total-volume (+ (var-get total-volume) price))
      (var-set total-fees-collected (+ (var-get total-fees-collected) protocol-fee))
      
      ;; Decrement seller's listing count
      (let (
        (current-count (default-to u0 (map-get? seller-listing-count seller)))
      )
        (if (> current-count u0)
          (map-set seller-listing-count seller (- current-count u1))
          true
        )
      )
      
      (print {
        event: "listing-sold",
        listing-id: listing-id,
        seller: seller,
        buyer: tx-sender,
        nft-contract: nft-principal,
        token-id: token-id,
        price: price,
        protocol-fee: protocol-fee,
        seller-proceeds: seller-proceeds
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

;; Set protocol fee (max 10% = 1000 bps)
(define-public (set-protocol-fee-bps (new-fee-bps uint))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee-bps u1000) ERR-INVALID-PRICE) ;; Max 10%
    (var-set protocol-fee-bps new-fee-bps)
    (print { event: "protocol-fee-updated", new-fee-bps: new-fee-bps })
    (ok true)
  )
)

;; Set fee recipient
(define-public (set-fee-recipient (recipient principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set fee-recipient recipient)
    (print { event: "fee-recipient-updated", recipient: recipient })
    (ok true)
  )
)

;; Set escrow contract reference
(define-public (set-escrow-contract (contract principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set escrow-contract contract)
    (print { event: "escrow-contract-updated", contract: contract })
    (ok true)
  )
)

;; Set royalty contract reference
(define-public (set-royalty-contract (contract principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set royalty-contract contract)
    (print { event: "royalty-contract-updated", contract: contract })
    (ok true)
  )
)

;; Set auction contract reference
(define-public (set-auction-contract (contract principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set auction-contract contract)
    (print { event: "auction-contract-updated", contract: contract })
    (ok true)
  )
)

;; ============================================
;; EMERGENCY FUNCTIONS
;; ============================================

;; Force cancel listing (owner only, for emergencies)
(define-public (emergency-cancel-listing (listing-id uint))
  (let (
    (listing (unwrap! (map-get? listings listing-id) ERR-NOT-FOUND))
  )
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    
    ;; Deactivate listing
    (map-set listings listing-id (merge listing { is-active: false }))
    
    ;; Remove NFT mapping
    (map-delete nft-to-listing { 
      nft-contract: (get nft-contract listing), 
      token-id: (get token-id listing) 
    })
    
    (print {
      event: "emergency-listing-cancelled",
      listing-id: listing-id
    })
    
    (ok true)
  )
)
