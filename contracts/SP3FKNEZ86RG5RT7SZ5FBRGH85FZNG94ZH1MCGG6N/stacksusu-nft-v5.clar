;; StackSusu NFT v5
;; Enhanced slot NFTs with marketplace and reputation integration

(define-constant CONTRACT-OWNER tx-sender)

;; Error constants
(define-constant ERR-NOT-AUTHORIZED (err u5000))
(define-constant ERR-NOT-FOUND (err u5001))
(define-constant ERR-ALREADY-MINTED (err u5002))
(define-constant ERR-NOT-OWNER (err u5003))
(define-constant ERR-LISTING-NOT-FOUND (err u5004))
(define-constant ERR-WRONG-PRICE (err u5005))
(define-constant ERR-CANNOT-TRANSFER (err u5006))
(define-constant ERR-CIRCLE-NOT-TRADEABLE (err u5007))
(define-constant ERR-SELF-TRANSFER (err u5008))
(define-constant ERR-PAUSED (err u5009))
(define-constant ERR-TRANSFER-FAILED (err u5010))
(define-constant ERR-REPUTATION-TOO-LOW (err u5011))

;; NFT definition
(define-non-fungible-token stacksusu-slot uint)

;; Token counters and config
(define-data-var token-id-counter uint u0)
(define-data-var base-uri (string-ascii 256) "https://api.stacksusu.xyz/metadata/")
(define-data-var marketplace-fee-bps uint u250)  ;; 2.5% marketplace fee

;; Token metadata
(define-map token-metadata
  uint
  { 
    circle-id: uint, 
    slot: uint, 
    original-owner: principal, 
    minted-at: uint,
    transfers: uint,
    last-transfer-block: uint
  }
)

;; Mappings
(define-map slot-to-token
  { circle-id: uint, slot: uint }
  uint
)

(define-map slot-holder
  { circle-id: uint, slot: uint }
  principal
)

;; Marketplace listings
(define-map listings
  uint
  { price: uint, seller: principal, listed-at: uint, expires-at: uint }
)

;; Offers on tokens
(define-map offers
  { token-id: uint, offerer: principal }
  { amount: uint, offered-at: uint, expires-at: uint }
)

;; Circle trading settings
(define-map circle-trading-enabled uint bool)
(define-map circle-min-reputation uint uint)  ;; Min reputation to buy/receive NFT

;; Authorized minters
(define-map authorized-minters principal bool)

;; Marketplace stats
(define-data-var total-volume uint u0)
(define-data-var total-sales uint u0)


;; ============================================
;; SIP-009 Implementation
;; ============================================

(define-read-only (get-last-token-id)
  (ok (var-get token-id-counter))
)

(define-read-only (get-token-uri (token-id uint))
  (ok (some (var-get base-uri)))
)

(define-read-only (get-owner (token-id uint))
  (ok (nft-get-owner? stacksusu-slot token-id))
)

(define-public (transfer (token-id uint) (sender principal) (recipient principal))
  (let
    (
      (token-info (unwrap! (map-get? token-metadata token-id) ERR-NOT-FOUND))
      (circle-id (get circle-id token-info))
      (slot (get slot token-info))
      (min-rep (default-to u0 (map-get? circle-min-reputation circle-id)))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v5 is-paused)) ERR-PAUSED)
    (asserts! (is-eq tx-sender sender) ERR-NOT-AUTHORIZED)
    (asserts! (not (is-eq sender recipient)) ERR-SELF-TRANSFER)
    (asserts! (is-trading-enabled circle-id) ERR-CIRCLE-NOT-TRADEABLE)
    (asserts! (is-eq (some sender) (nft-get-owner? stacksusu-slot token-id)) ERR-NOT-OWNER)
    
    ;; Check recipient reputation if required
    (if (> min-rep u0)
      (asserts! (contract-call? .stacksusu-reputation-v5 meets-requirement recipient min-rep)
                ERR-REPUTATION-TOO-LOW)
      true
    )
    
    ;; Transfer NFT
    (try! (nft-transfer? stacksusu-slot token-id sender recipient))
    
    ;; Update slot holder in core contract
    (try! (contract-call? .stacksusu-core-v5 update-slot-holder circle-id slot recipient))
    
    ;; Update local tracking
    (map-set slot-holder { circle-id: circle-id, slot: slot } recipient)
    
    ;; Update metadata
    (map-set token-metadata token-id
      (merge token-info {
        transfers: (+ (get transfers token-info) u1),
        last-transfer-block: block-height
      })
    )
    
    ;; Remove any listings
    (map-delete listings token-id)
    
    (ok true)
  )
)


;; ============================================
;; Minting
;; ============================================

(define-read-only (is-authorized-minter (caller principal))
  (or (is-eq caller CONTRACT-OWNER) (default-to false (map-get? authorized-minters caller)))
)

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

(define-public (mint-slot-nft (circle-id uint) (slot uint) (member principal))
  (let 
    (
      (token-id (+ (var-get token-id-counter) u1))
    )
    (asserts! (is-authorized-minter contract-caller) ERR-NOT-AUTHORIZED)
    (asserts! (is-none (map-get? slot-to-token { circle-id: circle-id, slot: slot })) ERR-ALREADY-MINTED)
    
    ;; Mint NFT
    (try! (nft-mint? stacksusu-slot token-id member))
    
    ;; Store metadata
    (map-set token-metadata token-id
      { 
        circle-id: circle-id, 
        slot: slot, 
        original-owner: member, 
        minted-at: block-height,
        transfers: u0,
        last-transfer-block: u0
      }
    )
    
    (map-set slot-to-token { circle-id: circle-id, slot: slot } token-id)
    (map-set slot-holder { circle-id: circle-id, slot: slot } member)
    
    (var-set token-id-counter token-id)
    (ok token-id)
  )
)


;; ============================================
;; Marketplace
;; ============================================

(define-public (list-token (token-id uint) (price uint) (duration-blocks uint))
  (let
    (
      (token-info (unwrap! (map-get? token-metadata token-id) ERR-NOT-FOUND))
      (owner (unwrap! (nft-get-owner? stacksusu-slot token-id) ERR-NOT-FOUND))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v5 is-paused)) ERR-PAUSED)
    (asserts! (is-eq tx-sender owner) ERR-NOT-OWNER)
    (asserts! (is-trading-enabled (get circle-id token-info)) ERR-CIRCLE-NOT-TRADEABLE)
    (asserts! (> price u0) ERR-WRONG-PRICE)
    
    (map-set listings token-id
      { 
        price: price, 
        seller: owner, 
        listed-at: block-height,
        expires-at: (+ block-height duration-blocks)
      }
    )
    (ok true)
  )
)

(define-public (unlist-token (token-id uint))
  (let
    (
      (listing (unwrap! (map-get? listings token-id) ERR-LISTING-NOT-FOUND))
    )
    (asserts! (is-eq tx-sender (get seller listing)) ERR-NOT-AUTHORIZED)
    (map-delete listings token-id)
    (ok true)
  )
)

(define-public (buy-token (token-id uint))
  (let
    (
      (listing (unwrap! (map-get? listings token-id) ERR-LISTING-NOT-FOUND))
      (token-info (unwrap! (map-get? token-metadata token-id) ERR-NOT-FOUND))
      (buyer tx-sender)
      (seller (get seller listing))
      (price (get price listing))
      (marketplace-fee (/ (* price (var-get marketplace-fee-bps)) u10000))
      (seller-proceeds (- price marketplace-fee))
      (circle-id (get circle-id token-info))
      (slot (get slot token-info))
      (min-rep (default-to u0 (map-get? circle-min-reputation circle-id)))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v5 is-paused)) ERR-PAUSED)
    (asserts! (< block-height (get expires-at listing)) ERR-LISTING-NOT-FOUND)
    (asserts! (not (is-eq buyer seller)) ERR-SELF-TRANSFER)
    
    ;; Check buyer reputation
    (if (> min-rep u0)
      (asserts! (contract-call? .stacksusu-reputation-v5 meets-requirement buyer min-rep)
                ERR-REPUTATION-TOO-LOW)
      true
    )
    
    ;; Transfer payment
    (try! (stx-transfer? seller-proceeds buyer seller))
    
    ;; Transfer marketplace fee to treasury
    (if (> marketplace-fee u0)
      (try! (stx-transfer? marketplace-fee buyer (contract-call? .stacksusu-admin-v5 get-treasury)))
      true
    )
    
    ;; Transfer NFT
    (try! (nft-transfer? stacksusu-slot token-id seller buyer))
    
    ;; Update slot holder
    (try! (contract-call? .stacksusu-core-v5 update-slot-holder circle-id slot buyer))
    (map-set slot-holder { circle-id: circle-id, slot: slot } buyer)
    
    ;; Update metadata
    (map-set token-metadata token-id
      (merge token-info {
        transfers: (+ (get transfers token-info) u1),
        last-transfer-block: block-height
      })
    )
    
    ;; Remove listing
    (map-delete listings token-id)
    
    ;; Update stats
    (var-set total-volume (+ (var-get total-volume) price))
    (var-set total-sales (+ (var-get total-sales) u1))
    
    (ok true)
  )
)


;; ============================================
;; Offers
;; ============================================

(define-public (make-offer (token-id uint) (amount uint) (duration-blocks uint))
  (let
    (
      (token-info (unwrap! (map-get? token-metadata token-id) ERR-NOT-FOUND))
      (offerer tx-sender)
      (min-rep (default-to u0 (map-get? circle-min-reputation (get circle-id token-info))))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v5 is-paused)) ERR-PAUSED)
    (asserts! (> amount u0) ERR-WRONG-PRICE)
    
    ;; Check offerer reputation
    (if (> min-rep u0)
      (asserts! (contract-call? .stacksusu-reputation-v5 meets-requirement offerer min-rep)
                ERR-REPUTATION-TOO-LOW)
      true
    )
    
    ;; Lock offer amount
    (try! (stx-transfer? amount offerer (as-contract tx-sender)))
    
    (map-set offers 
      { token-id: token-id, offerer: offerer }
      { amount: amount, offered-at: block-height, expires-at: (+ block-height duration-blocks) }
    )
    (ok true)
  )
)

(define-public (cancel-offer (token-id uint))
  (let
    (
      (offerer tx-sender)
      (offer (unwrap! (map-get? offers { token-id: token-id, offerer: offerer }) ERR-NOT-FOUND))
    )
    ;; Return locked STX
    (try! (as-contract (stx-transfer? (get amount offer) tx-sender offerer)))
    (map-delete offers { token-id: token-id, offerer: offerer })
    (ok true)
  )
)

(define-public (accept-offer (token-id uint) (offerer principal))
  (let
    (
      (token-info (unwrap! (map-get? token-metadata token-id) ERR-NOT-FOUND))
      (offer (unwrap! (map-get? offers { token-id: token-id, offerer: offerer }) ERR-NOT-FOUND))
      (seller tx-sender)
      (amount (get amount offer))
      (marketplace-fee (/ (* amount (var-get marketplace-fee-bps)) u10000))
      (seller-proceeds (- amount marketplace-fee))
      (circle-id (get circle-id token-info))
      (slot (get slot token-info))
    )
    (asserts! (not (contract-call? .stacksusu-admin-v5 is-paused)) ERR-PAUSED)
    (asserts! (is-eq (some seller) (nft-get-owner? stacksusu-slot token-id)) ERR-NOT-OWNER)
    (asserts! (< block-height (get expires-at offer)) ERR-NOT-FOUND)
    
    ;; Transfer proceeds to seller
    (try! (as-contract (stx-transfer? seller-proceeds tx-sender seller)))
    
    ;; Transfer fee to treasury
    (if (> marketplace-fee u0)
      (try! (as-contract (stx-transfer? marketplace-fee tx-sender (contract-call? .stacksusu-admin-v5 get-treasury))))
      true
    )
    
    ;; Transfer NFT
    (try! (nft-transfer? stacksusu-slot token-id seller offerer))
    
    ;; Update slot holder
    (try! (contract-call? .stacksusu-core-v5 update-slot-holder circle-id slot offerer))
    (map-set slot-holder { circle-id: circle-id, slot: slot } offerer)
    
    ;; Update metadata
    (map-set token-metadata token-id
      (merge token-info {
        transfers: (+ (get transfers token-info) u1),
        last-transfer-block: block-height
      })
    )
    
    ;; Remove offer and any listing
    (map-delete offers { token-id: token-id, offerer: offerer })
    (map-delete listings token-id)
    
    ;; Update stats
    (var-set total-volume (+ (var-get total-volume) amount))
    (var-set total-sales (+ (var-get total-sales) u1))
    
    (ok true)
  )
)


;; ============================================
;; Trading Settings
;; ============================================

(define-public (set-trading-enabled (circle-id uint) (enabled bool))
  (let
    (
      (circle-info (unwrap! (contract-call? .stacksusu-core-v5 get-circle-info circle-id) ERR-NOT-FOUND))
      (circle (unwrap! circle-info ERR-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender (get creator circle)) (is-eq tx-sender CONTRACT-OWNER)) 
              ERR-NOT-AUTHORIZED)
    (ok (map-set circle-trading-enabled circle-id enabled))
  )
)

(define-public (set-circle-min-reputation (circle-id uint) (min-rep uint))
  (let
    (
      (circle-info (unwrap! (contract-call? .stacksusu-core-v5 get-circle-info circle-id) ERR-NOT-FOUND))
      (circle (unwrap! circle-info ERR-NOT-FOUND))
    )
    (asserts! (or (is-eq tx-sender (get creator circle)) (is-eq tx-sender CONTRACT-OWNER)) 
              ERR-NOT-AUTHORIZED)
    (ok (map-set circle-min-reputation circle-id min-rep))
  )
)

(define-public (set-marketplace-fee (new-fee-bps uint))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (asserts! (<= new-fee-bps u1000) ERR-NOT-AUTHORIZED)  ;; Max 10%
    (ok (var-set marketplace-fee-bps new-fee-bps))
  )
)

(define-public (set-base-uri (new-uri (string-ascii 256)))
  (begin
    (asserts! (is-eq tx-sender CONTRACT-OWNER) ERR-NOT-AUTHORIZED)
    (ok (var-set base-uri new-uri))
  )
)


;; ============================================
;; Read-only Functions
;; ============================================

(define-read-only (is-trading-enabled (circle-id uint))
  (default-to false (map-get? circle-trading-enabled circle-id))
)

(define-read-only (get-token-by-slot (circle-id uint) (slot uint))
  (ok (map-get? slot-to-token { circle-id: circle-id, slot: slot }))
)

(define-read-only (get-slot-holder (circle-id uint) (slot uint))
  (ok (map-get? slot-holder { circle-id: circle-id, slot: slot }))
)

(define-read-only (get-token-metadata (token-id uint))
  (ok (map-get? token-metadata token-id))
)

(define-read-only (get-listing (token-id uint))
  (ok (map-get? listings token-id))
)

(define-read-only (get-offer (token-id uint) (offerer principal))
  (ok (map-get? offers { token-id: token-id, offerer: offerer }))
)

(define-read-only (get-marketplace-stats)
  {
    total-volume: (var-get total-volume),
    total-sales: (var-get total-sales),
    marketplace-fee-bps: (var-get marketplace-fee-bps)
  }
)

(define-read-only (get-floor-price (circle-id uint))
  ;; Would need to iterate listings - simplified for now
  (ok u0)
)
