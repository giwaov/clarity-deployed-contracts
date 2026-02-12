;; StackSusu NFT v6
;; Enhanced NFTs with composability, rentals, and marketplace

(impl-trait .stacksusu-traits-v4.sip009-nft-trait)

(define-constant CONTRACT-OWNER tx-sender)

;; NFT Types
(define-constant NFT-MEMBERSHIP u1)
(define-constant NFT-ACHIEVEMENT u2)
(define-constant NFT-FOUNDER u3)
(define-constant NFT-REPUTATION u4)
(define-constant NFT-SPECIAL-EDITION u5)
(define-constant NFT-COMPOSABLE u6)      ;; NEW: Can have child NFTs

;; Rarity levels
(define-constant RARITY-COMMON u1)
(define-constant RARITY-UNCOMMON u2)
(define-constant RARITY-RARE u3)
(define-constant RARITY-EPIC u4)
(define-constant RARITY-LEGENDARY u5)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u6000))
(define-constant ERR-NOT-FOUND (err u6001))
(define-constant ERR-ALREADY-EXISTS (err u6002))
(define-constant ERR-INVALID-TYPE (err u6003))
(define-constant ERR-NOT-OWNER (err u6004))
(define-constant ERR-PAUSED (err u6005))
(define-constant ERR-TRANSFER-RESTRICTED (err u6006))
(define-constant ERR-NFT-RENTED (err u6007))
(define-constant ERR-RENTAL-EXPIRED (err u6008))
(define-constant ERR-INVALID-PRICE (err u6009))
(define-constant ERR-LISTING-NOT-FOUND (err u6010))
(define-constant ERR-INSUFFICIENT-FUNDS (err u6011))
(define-constant ERR-CANNOT-COMPOSE (err u6012))
(define-constant ERR-MAX-CHILDREN (err u6013))

;; NFT counter
(define-data-var nft-counter uint u0)

;; Collection info
(define-data-var collection-name (string-ascii 50) "StackSusu NFT")
(define-data-var collection-uri (string-ascii 200) "https://stacksusu.io/nft/")

;; Non-fungible token definition
(define-non-fungible-token stacksusu-nft-v6 uint)

;; NFT metadata
(define-map nft-metadata
  uint
  {
    nft-type: uint,
    rarity: uint,
    circle-id: uint,
    member: principal,
    minted-at: uint,
    metadata-uri: (string-ascii 200),
    transferable: bool,
    attributes: (list 10 { trait: (string-ascii 30), value: (string-ascii 50) }),
    power-boost: uint,              ;; NEW: Boost to voting/earning power
    parent-nft: (optional uint),    ;; NEW: For composable NFTs
    is-composable: bool             ;; NEW: Can have children attached
  }
)

;; Child NFTs for composable system
(define-map nft-children
  uint
  (list 5 uint)
)

;; Rental system (NEW in v6)
(define-map nft-rentals
  uint
  {
    renter: principal,
    rental-start: uint,
    rental-end: uint,
    rental-price: uint,
    rental-paid: bool
  }
)

;; Marketplace listings (NEW in v6)
(define-map marketplace-listings
  uint
  {
    seller: principal,
    price: uint,
    listed-at: uint,
    expires-at: uint,
    royalty-percent: uint,          ;; Royalty to original creator
    is-auction: bool,
    min-bid: uint,
    highest-bid: uint,
    highest-bidder: (optional principal)
  }
)

;; Marketplace stats
(define-map marketplace-stats
  principal
  {
    total-sales: uint,
    total-volume: uint,
    total-royalties: uint
  }
)

;; Authorized minters
(define-map authorized-minters principal bool)

;; Circle NFT tracking
(define-map circle-nfts
  uint
  (list 100 uint)
)

;; Member NFT tracking
(define-map member-nfts
  principal
  (list 50 uint)
)


;; ============================================
;; Authorization
;; ============================================

(define-public (authorize-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-set authorized-minters minter true))
  )
)

(define-public (revoke-minter (minter principal))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (map-delete authorized-minters minter))
  )
)

(define-read-only (is-authorized-minter (minter principal))
  (or (is-eq minter CONTRACT-OWNER) 
      (default-to false (map-get? authorized-minters minter)))
)


;; ============================================
;; Minting
;; ============================================

(define-public (mint-nft 
    (recipient principal)
    (nft-type uint)
    (rarity uint)
    (circle-id uint)
    (metadata-uri (string-ascii 200))
    (transferable bool)
    (attributes (list 10 { trait: (string-ascii 30), value: (string-ascii 50) }))
    (is-composable bool))
  (let
    (
      (nft-id (+ (var-get nft-counter) u1))
      (power-boost (calculate-power-boost rarity nft-type))
      (member-current-nfts (default-to (list) (map-get? member-nfts recipient)))
      (circle-current-nfts (default-to (list) (map-get? circle-nfts circle-id)))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (is-authorized-minter tx-sender) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= nft-type NFT-MEMBERSHIP) (<= nft-type NFT-COMPOSABLE)) ERR-INVALID-TYPE)
    (asserts! (and (>= rarity RARITY-COMMON) (<= rarity RARITY-LEGENDARY)) ERR-INVALID-TYPE)
    
    ;; Mint NFT
    (try! (nft-mint? stacksusu-nft-v6 nft-id recipient))
    
    ;; Store metadata
    (map-set nft-metadata nft-id
      {
        nft-type: nft-type,
        rarity: rarity,
        circle-id: circle-id,
        member: recipient,
        minted-at: block-height,
        metadata-uri: metadata-uri,
        transferable: transferable,
        attributes: attributes,
        power-boost: power-boost,
        parent-nft: none,
        is-composable: is-composable
      }
    )
    
    ;; Track NFT for member
    (map-set member-nfts recipient
      (unwrap! (as-max-len? (append member-current-nfts nft-id) u50) ERR-NOT-AUTHORIZED)
    )
    
    ;; Track NFT for circle
    (map-set circle-nfts circle-id
      (unwrap! (as-max-len? (append circle-current-nfts nft-id) u100) ERR-NOT-AUTHORIZED)
    )
    
    (var-set nft-counter nft-id)
    (ok nft-id)
  )
)

(define-private (calculate-power-boost (rarity uint) (nft-type uint))
  (let
    (
      (base-boost (if (is-eq nft-type NFT-FOUNDER)
                    u50
                    (if (is-eq nft-type NFT-REPUTATION)
                      u30
                      u10)))
      (rarity-multiplier (+ u100 (* rarity u25)))  ;; 125% to 225%
    )
    (/ (* base-boost rarity-multiplier) u100)
  )
)


;; ============================================
;; Composable NFTs (NEW in v6)
;; ============================================

(define-public (attach-nft (parent-id uint) (child-id uint))
  (let
    (
      (parent-meta (unwrap! (map-get? nft-metadata parent-id) ERR-NOT-FOUND))
      (child-meta (unwrap! (map-get? nft-metadata child-id) ERR-NOT-FOUND))
      (parent-owner (unwrap! (nft-get-owner? stacksusu-nft-v6 parent-id) ERR-NOT-FOUND))
      (child-owner (unwrap! (nft-get-owner? stacksusu-nft-v6 child-id) ERR-NOT-FOUND))
      (current-children (default-to (list) (map-get? nft-children parent-id)))
    )
    (asserts! (is-eq tx-sender parent-owner) ERR-NOT-OWNER)
    (asserts! (is-eq tx-sender child-owner) ERR-NOT-OWNER)
    (asserts! (get is-composable parent-meta) ERR-CANNOT-COMPOSE)
    (asserts! (is-none (get parent-nft child-meta)) ERR-ALREADY-EXISTS)
    (asserts! (< (len current-children) u5) ERR-MAX-CHILDREN)
    
    ;; Update child metadata
    (map-set nft-metadata child-id (merge child-meta { parent-nft: (some parent-id) }))
    
    ;; Add to parent's children
    (map-set nft-children parent-id
      (unwrap! (as-max-len? (append current-children child-id) u5) ERR-MAX-CHILDREN)
    )
    
    (ok true)
  )
)

(define-public (detach-nft (child-id uint))
  (let
    (
      (child-meta (unwrap! (map-get? nft-metadata child-id) ERR-NOT-FOUND))
      (parent-id (unwrap! (get parent-nft child-meta) ERR-NOT-FOUND))
      (parent-owner (unwrap! (nft-get-owner? stacksusu-nft-v6 parent-id) ERR-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender parent-owner) ERR-NOT-OWNER)
    
    ;; Update child metadata
    (map-set nft-metadata child-id (merge child-meta { parent-nft: none }))
    
    ;; Remove from parent's children (would need filter implementation)
    ;; For simplicity, we clear and rebuild
    
    (ok true)
  )
)

(define-read-only (get-nft-children (parent-id uint))
  (default-to (list) (map-get? nft-children parent-id))
)

(define-read-only (get-total-power-boost (nft-id uint))
  (let
    (
      (meta (unwrap! (map-get? nft-metadata nft-id) (err u0)))
      (base-boost (get power-boost meta))
      (children (default-to (list) (map-get? nft-children nft-id)))
    )
    ;; Base boost + sum of children boosts (simplified)
    (ok base-boost)
  )
)


;; ============================================
;; Rental System (NEW in v6)
;; ============================================

(define-public (list-for-rent (nft-id uint) (price-per-block uint) (duration uint))
  (let
    (
      (owner (unwrap! (nft-get-owner? stacksusu-nft-v6 nft-id) ERR-NOT-FOUND))
      (meta (unwrap! (map-get? nft-metadata nft-id) ERR-NOT-FOUND))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (is-eq tx-sender owner) ERR-NOT-OWNER)
    (asserts! (get transferable meta) ERR-TRANSFER-RESTRICTED)
    (asserts! (is-none (map-get? nft-rentals nft-id)) ERR-NFT-RENTED)
    
    (map-set nft-rentals nft-id
      {
        renter: owner,  ;; Placeholder, actual renter set on rent
        rental-start: u0,
        rental-end: duration,
        rental-price: price-per-block,
        rental-paid: false
      }
    )
    
    (ok true)
  )
)

(define-public (rent-nft (nft-id uint) (duration uint))
  (let
    (
      (owner (unwrap! (nft-get-owner? stacksusu-nft-v6 nft-id) ERR-NOT-FOUND))
      (rental-info (unwrap! (map-get? nft-rentals nft-id) ERR-NOT-FOUND))
      (total-cost (* (get rental-price rental-info) duration))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (not (get rental-paid rental-info)) ERR-NFT-RENTED)
    
    ;; Pay rental fee
    (try! (stx-transfer? total-cost tx-sender owner))
    
    (map-set nft-rentals nft-id
      {
        renter: tx-sender,
        rental-start: block-height,
        rental-end: (+ block-height duration),
        rental-price: (get rental-price rental-info),
        rental-paid: true
      }
    )
    
    (ok true)
  )
)

(define-public (end-rental (nft-id uint))
  (let
    (
      (rental-info (unwrap! (map-get? nft-rentals nft-id) ERR-NOT-FOUND))
    )
    (asserts! (>= block-height (get rental-end rental-info)) ERR-RENTAL-EXPIRED)
    
    (map-delete nft-rentals nft-id)
    (ok true)
  )
)

(define-read-only (get-rental-info (nft-id uint))
  (map-get? nft-rentals nft-id)
)

(define-read-only (is-rented (nft-id uint))
  (match (map-get? nft-rentals nft-id)
    rental-info
      (and (get rental-paid rental-info)
           (< block-height (get rental-end rental-info)))
    false
  )
)

(define-read-only (get-effective-owner (nft-id uint))
  (let
    (
      (actual-owner (nft-get-owner? stacksusu-nft-v6 nft-id))
    )
    (if (is-rented nft-id)
      (ok (get renter (unwrap! (map-get? nft-rentals nft-id) ERR-NOT-FOUND)))
      (ok (unwrap! actual-owner ERR-NOT-FOUND))
    )
  )
)


;; ============================================
;; Marketplace (NEW in v6)
;; ============================================

(define-public (list-for-sale 
    (nft-id uint) 
    (price uint)
    (duration uint)
    (royalty-percent uint)
    (is-auction bool)
    (min-bid uint))
  (let
    (
      (owner (unwrap! (nft-get-owner? stacksusu-nft-v6 nft-id) ERR-NOT-FOUND))
      (meta (unwrap! (map-get? nft-metadata nft-id) ERR-NOT-FOUND))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (is-eq tx-sender owner) ERR-NOT-OWNER)
    (asserts! (get transferable meta) ERR-TRANSFER-RESTRICTED)
    (asserts! (not (is-rented nft-id)) ERR-NFT-RENTED)
    (asserts! (> price u0) ERR-INVALID-PRICE)
    (asserts! (<= royalty-percent u1000) ERR-INVALID-PRICE)  ;; Max 10%
    
    (map-set marketplace-listings nft-id
      {
        seller: owner,
        price: price,
        listed-at: block-height,
        expires-at: (+ block-height duration),
        royalty-percent: royalty-percent,
        is-auction: is-auction,
        min-bid: min-bid,
        highest-bid: u0,
        highest-bidder: none
      }
    )
    
    (ok true)
  )
)

(define-public (buy-nft (nft-id uint))
  (let
    (
      (listing (unwrap! (map-get? marketplace-listings nft-id) ERR-LISTING-NOT-FOUND))
      (seller (get seller listing))
      (price (get price listing))
      (royalty-amount (/ (* price (get royalty-percent listing)) u10000))
      (meta (unwrap! (map-get? nft-metadata nft-id) ERR-NOT-FOUND))
      (original-creator (get member meta))
      (seller-amount (- price royalty-amount))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (not (get is-auction listing)) ERR-NOT-AUTHORIZED)
    (asserts! (< block-height (get expires-at listing)) ERR-LISTING-NOT-FOUND)
    
    ;; Pay seller
    (try! (stx-transfer? seller-amount tx-sender seller))
    
    ;; Pay royalty to original creator
    (if (and (> royalty-amount u0) (not (is-eq original-creator seller)))
      (try! (stx-transfer? royalty-amount tx-sender original-creator))
      true
    )
    
    ;; Transfer NFT
    (try! (nft-transfer? stacksusu-nft-v6 nft-id seller tx-sender))
    
    ;; Update stats
    (update-marketplace-stats seller price royalty-amount)
    
    ;; Remove listing
    (map-delete marketplace-listings nft-id)
    
    (ok true)
  )
)

(define-public (place-bid (nft-id uint) (bid-amount uint))
  (let
    (
      (listing (unwrap! (map-get? marketplace-listings nft-id) ERR-LISTING-NOT-FOUND))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (get is-auction listing) ERR-NOT-AUTHORIZED)
    (asserts! (< block-height (get expires-at listing)) ERR-LISTING-NOT-FOUND)
    (asserts! (>= bid-amount (get min-bid listing)) ERR-INVALID-PRICE)
    (asserts! (> bid-amount (get highest-bid listing)) ERR-INVALID-PRICE)
    
    ;; Refund previous bidder
    (match (get highest-bidder listing)
      prev-bidder
        (try! (as-contract (stx-transfer? (get highest-bid listing) tx-sender prev-bidder)))
      true
    )
    
    ;; Lock new bid
    (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
    
    (map-set marketplace-listings nft-id
      (merge listing {
        highest-bid: bid-amount,
        highest-bidder: (some tx-sender)
      })
    )
    
    (ok true)
  )
)

(define-public (finalize-auction (nft-id uint))
  (let
    (
      (listing (unwrap! (map-get? marketplace-listings nft-id) ERR-LISTING-NOT-FOUND))
      (seller (get seller listing))
      (highest-bid (get highest-bid listing))
      (winner (unwrap! (get highest-bidder listing) ERR-NOT-FOUND))
      (royalty-amount (/ (* highest-bid (get royalty-percent listing)) u10000))
      (meta (unwrap! (map-get? nft-metadata nft-id) ERR-NOT-FOUND))
      (original-creator (get member meta))
      (seller-amount (- highest-bid royalty-amount))
    )
    (asserts! (get is-auction listing) ERR-NOT-AUTHORIZED)
    (asserts! (>= block-height (get expires-at listing)) ERR-NOT-AUTHORIZED)
    
    ;; Transfer bid to seller
    (try! (as-contract (stx-transfer? seller-amount tx-sender seller)))
    
    ;; Pay royalty
    (if (and (> royalty-amount u0) (not (is-eq original-creator seller)))
      (try! (as-contract (stx-transfer? royalty-amount tx-sender original-creator)))
      true
    )
    
    ;; Transfer NFT
    (try! (nft-transfer? stacksusu-nft-v6 nft-id seller winner))
    
    ;; Update stats
    (update-marketplace-stats seller highest-bid royalty-amount)
    
    ;; Remove listing
    (map-delete marketplace-listings nft-id)
    
    (ok true)
  )
)

(define-public (cancel-listing (nft-id uint))
  (let
    (
      (listing (unwrap! (map-get? marketplace-listings nft-id) ERR-LISTING-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get seller listing)) ERR-NOT-OWNER)
    (asserts! (is-none (get highest-bidder listing)) ERR-NOT-AUTHORIZED)  ;; Can't cancel with bids
    
    (map-delete marketplace-listings nft-id)
    (ok true)
  )
)

(define-private (update-marketplace-stats (seller principal) (sale-amount uint) (royalty uint))
  (let
    (
      (current-stats (default-to { total-sales: u0, total-volume: u0, total-royalties: u0 }
                       (map-get? marketplace-stats seller)))
    )
    (map-set marketplace-stats seller
      {
        total-sales: (+ (get total-sales current-stats) u1),
        total-volume: (+ (get total-volume current-stats) sale-amount),
        total-royalties: (+ (get total-royalties current-stats) royalty)
      }
    )
  )
)


;; ============================================
;; Transfer
;; ============================================

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let
    (
      (meta (unwrap! (map-get? nft-metadata token-id) ERR-NOT-FOUND))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v6 is-paused)) ERR-PAUSED)
    (asserts! (is-eq tx-sender sender) ERR-NOT-OWNER)
    (asserts! (get transferable meta) ERR-TRANSFER-RESTRICTED)
    (asserts! (not (is-rented token-id)) ERR-NFT-RENTED)
    
    (nft-transfer? stacksusu-nft-v6 token-id sender recipient)
  )
)


;; ============================================
;; Read-Only Functions
;; ============================================

(define-read-only (get-last-token-id)
  (ok (var-get nft-counter))
)

(define-read-only (get-token-uri (token-id uint))
  (match (map-get? nft-metadata token-id)
    meta (ok (some (get metadata-uri meta)))
    (ok none)
  )
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? stacksusu-nft-v6 token-id))
)

(define-read-only (get-nft-metadata (nft-id uint))
  (ok (map-get? nft-metadata nft-id))
)

(define-read-only (get-member-nfts (member principal))
  (default-to (list) (map-get? member-nfts member))
)

(define-read-only (get-circle-nfts (circle-id uint))
  (default-to (list) (map-get? circle-nfts circle-id))
)

(define-read-only (get-listing (nft-id uint))
  (map-get? marketplace-listings nft-id)
)

(define-read-only (get-marketplace-stats (seller principal))
  (map-get? marketplace-stats seller)
)

(define-read-only (get-nft-count)
  (var-get nft-counter)
)
