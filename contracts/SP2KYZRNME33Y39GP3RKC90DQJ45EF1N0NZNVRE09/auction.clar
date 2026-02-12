;; Gaga Finance Auction Contract
;; Timed auctions with bid tracking, anti-sniping, and settlement
;; Coordinates with Escrow and Royalty Engine for secure transactions

;; ============================================
;; CONSTANTS - Error Codes
;; ============================================
(define-constant ERR-NOT-AUTHORIZED (err u400))
(define-constant ERR-NOT-FOUND (err u401))
(define-constant ERR-AUCTION-EXISTS (err u402))
(define-constant ERR-AUCTION-NOT-ACTIVE (err u403))
(define-constant ERR-AUCTION-ENDED (err u404))
(define-constant ERR-AUCTION-NOT-ENDED (err u405))
(define-constant ERR-BID-TOO-LOW (err u406))
(define-constant ERR-CANNOT-BID-OWN-AUCTION (err u407))
(define-constant ERR-CONTRACT-PAUSED (err u408))
(define-constant ERR-INVALID-DURATION (err u409))
(define-constant ERR-INVALID-PRICE (err u410))
(define-constant ERR-TRANSFER-FAILED (err u411))
(define-constant ERR-NOT-SELLER (err u412))
(define-constant ERR-HAS-BIDS (err u413))
(define-constant ERR-ALREADY-HIGHEST-BIDDER (err u414))

;; ============================================
;; CONFIGURATION
;; ============================================
(define-constant CONTRACT-OWNER tx-sender)

;; Min/max auction durations in blocks (~10 min/block on Stacks)
(define-constant MIN-AUCTION-DURATION u144)     ;; ~1 day
(define-constant MAX-AUCTION-DURATION u10080)   ;; ~70 days

;; Anti-sniping: extend auction if bid in last N blocks
(define-constant ANTI-SNIPE-BLOCKS u6)          ;; ~1 hour
(define-constant ANTI-SNIPE-EXTENSION u6)       ;; extend by ~1 hour

;; Minimum bid increment (basis points)
(define-constant MIN-BID-INCREMENT-BPS u500)    ;; 5% minimum increment

;; Protocol fee (basis points)
(define-constant PROTOCOL-FEE-BPS u250)         ;; 2.5%

;; ============================================
;; DATA VARIABLES
;; ============================================
(define-data-var is-paused bool false)
(define-data-var next-auction-id uint u1)
(define-data-var fee-recipient principal CONTRACT-OWNER)
(define-data-var escrow-contract principal CONTRACT-OWNER)
(define-data-var royalty-contract principal CONTRACT-OWNER)
(define-data-var marketplace-contract principal CONTRACT-OWNER)

;; ============================================
;; DATA MAPS
;; ============================================

;; Auction data
(define-map auctions uint {
  seller: principal,
  nft-contract: principal,
  token-id: uint,
  start-price: uint,
  reserve-price: uint,
  current-bid: uint,
  highest-bidder: (optional principal),
  start-block: uint,
  end-block: uint,
  is-active: bool,
  is-settled: bool
})

;; Bid tracking
(define-map bids { auction-id: uint, bidder: principal } uint)

;; Auction ID by NFT
(define-map nft-to-auction { nft-contract: principal, token-id: uint } uint)

;; Stats
(define-data-var total-auctions-created uint u0)
(define-data-var total-auctions-settled uint u0)
(define-data-var total-volume uint u0)

;; ============================================
;; AUTHORIZATION
;; ============================================

(define-private (is-contract-owner)
  (is-eq tx-sender CONTRACT-OWNER)
)

(define-private (is-marketplace-caller)
  (is-eq contract-caller (var-get marketplace-contract))
)

(define-private (assert-not-paused)
  (ok (asserts! (not (var-get is-paused)) ERR-CONTRACT-PAUSED))
)

;; ============================================
;; READ-ONLY FUNCTIONS
;; ============================================

;; Get auction by ID
(define-read-only (get-auction (auction-id uint))
  (ok (map-get? auctions auction-id))
)

;; Get auction ID for an NFT
(define-read-only (get-auction-by-nft (nft-contract principal) (token-id uint))
  (ok (map-get? nft-to-auction { nft-contract: nft-contract, token-id: token-id }))
)

;; Check if auction is active
(define-read-only (is-auction-active (auction-id uint))
  (match (map-get? auctions auction-id)
    auction (and 
      (get is-active auction)
      (not (get is-settled auction))
      (<= stacks-block-height (get end-block auction))
    )
    false
  )
)

;; Check if auction has ended
(define-read-only (has-auction-ended (auction-id uint))
  (match (map-get? auctions auction-id)
    auction (> stacks-block-height (get end-block auction))
    true
  )
)

;; Get current bid for bidder
(define-read-only (get-bid (auction-id uint) (bidder principal))
  (ok (map-get? bids { auction-id: auction-id, bidder: bidder }))
)

;; Get minimum next bid amount
(define-read-only (get-min-next-bid (auction-id uint))
  (match (map-get? auctions auction-id)
    auction (let (
      (current (get current-bid auction))
      (start-price (get start-price auction))
      (base-amount (if (> current u0) current start-price))
      (increment (/ (* base-amount MIN-BID-INCREMENT-BPS) u10000))
    )
      (ok (+ base-amount increment))
    )
    ERR-NOT-FOUND
  )
)

;; Get remaining blocks until auction ends
(define-read-only (get-remaining-blocks (auction-id uint))
  (match (map-get? auctions auction-id)
    auction (if (> (get end-block auction) stacks-block-height)
      (ok (- (get end-block auction) stacks-block-height))
      (ok u0)
    )
    ERR-NOT-FOUND
  )
)

;; Get next auction ID
(define-read-only (get-next-auction-id)
  (ok (var-get next-auction-id))
)

;; Get protocol config
(define-read-only (get-protocol-fee-bps)
  (ok PROTOCOL-FEE-BPS)
)

;; Get stats
(define-read-only (get-stats)
  (ok {
    total-created: (var-get total-auctions-created),
    total-settled: (var-get total-auctions-settled),
    total-volume: (var-get total-volume)
  })
)

;; Check pause status
(define-read-only (is-contract-paused)
  (ok (var-get is-paused))
)

;; ============================================
;; PUBLIC FUNCTIONS - AUCTION CREATION
;; ============================================

;; Create a new auction
(define-public (create-auction 
  (nft-contract principal)
  (token-id uint)
  (start-price uint)
  (reserve-price uint)
  (duration-blocks uint)
)
  (let (
    (auction-id (var-get next-auction-id))
    (end-block (+ stacks-block-height duration-blocks))
  )
    (try! (assert-not-paused))
    
    ;; Validate duration
    (asserts! (>= duration-blocks MIN-AUCTION-DURATION) ERR-INVALID-DURATION)
    (asserts! (<= duration-blocks MAX-AUCTION-DURATION) ERR-INVALID-DURATION)
    
    ;; Validate prices
    (asserts! (> start-price u0) ERR-INVALID-PRICE)
    (asserts! (>= reserve-price start-price) ERR-INVALID-PRICE)
    
    ;; Check NFT not already in auction
    (asserts! (is-none (map-get? nft-to-auction { nft-contract: nft-contract, token-id: token-id })) ERR-AUCTION-EXISTS)
    
    ;; Create auction record
    (map-set auctions auction-id {
      seller: tx-sender,
      nft-contract: nft-contract,
      token-id: token-id,
      start-price: start-price,
      reserve-price: reserve-price,
      current-bid: u0,
      highest-bidder: none,
      start-block: stacks-block-height,
      end-block: end-block,
      is-active: true,
      is-settled: false
    })
    
    ;; Map NFT to auction
    (map-set nft-to-auction { nft-contract: nft-contract, token-id: token-id } auction-id)
    
    ;; Increment counters
    (var-set next-auction-id (+ auction-id u1))
    (var-set total-auctions-created (+ (var-get total-auctions-created) u1))
    
    (print {
      event: "auction-created",
      auction-id: auction-id,
      seller: tx-sender,
      nft-contract: nft-contract,
      token-id: token-id,
      start-price: start-price,
      reserve-price: reserve-price,
      end-block: end-block
    })
    
    (ok auction-id)
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - BIDDING
;; ============================================

;; Place a bid on an auction
(define-public (place-bid (auction-id uint) (bid-amount uint))
  (let (
    (auction (unwrap! (map-get? auctions auction-id) ERR-NOT-FOUND))
  )
    (try! (assert-not-paused))
    
    ;; Check auction is active
    (asserts! (get is-active auction) ERR-AUCTION-NOT-ACTIVE)
    (asserts! (<= stacks-block-height (get end-block auction)) ERR-AUCTION-ENDED)
    
    ;; Cannot bid on own auction
    (asserts! (not (is-eq tx-sender (get seller auction))) ERR-CANNOT-BID-OWN-AUCTION)
    
    ;; Cannot bid if already highest bidder
    (asserts! (not (is-eq (some tx-sender) (get highest-bidder auction))) ERR-ALREADY-HIGHEST-BIDDER)
    
    ;; Validate bid amount
    (let (
      (current (get current-bid auction))
      (start-price (get start-price auction))
      (min-bid (if (> current u0)
        (+ current (/ (* current MIN-BID-INCREMENT-BPS) u10000))
        start-price
      ))
    )
      (asserts! (>= bid-amount min-bid) ERR-BID-TOO-LOW)
      
      ;; Transfer bid from bidder to contract
      (try! (stx-transfer? bid-amount tx-sender (as-contract tx-sender)))
      
      ;; Refund previous highest bidder
      (match (get highest-bidder auction)
        prev-bidder (try! (as-contract (stx-transfer? current tx-sender prev-bidder)))
        true
      )
      
      ;; Anti-sniping: extend auction if bid in last N blocks
      (let (
        (new-end-block (if (<= (- (get end-block auction) stacks-block-height) ANTI-SNIPE-BLOCKS)
          (+ (get end-block auction) ANTI-SNIPE-EXTENSION)
          (get end-block auction)
        ))
      )
        ;; Update auction
        (map-set auctions auction-id (merge auction {
          current-bid: bid-amount,
          highest-bidder: (some tx-sender),
          end-block: new-end-block
        }))
        
        ;; Record bid
        (map-set bids { auction-id: auction-id, bidder: tx-sender } bid-amount)
        
        (print {
          event: "bid-placed",
          auction-id: auction-id,
          bidder: tx-sender,
          bid-amount: bid-amount,
          new-end-block: new-end-block,
          anti-snipe-triggered: (> new-end-block (get end-block auction))
        })
        
        (ok true)
      )
    )
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - SETTLEMENT
;; ============================================

;; Settle (finalize) an auction
(define-public (settle-auction (auction-id uint))
  (let (
    (auction (unwrap! (map-get? auctions auction-id) ERR-NOT-FOUND))
  )
    (try! (assert-not-paused))
    
    ;; Check auction has ended
    (asserts! (> stacks-block-height (get end-block auction)) ERR-AUCTION-NOT-ENDED)
    
    ;; Check not already settled
    (asserts! (not (get is-settled auction)) ERR-NOT-FOUND)
    
    ;; Check auction was active
    (asserts! (get is-active auction) ERR-AUCTION-NOT-ACTIVE)
    
    (let (
      (final-bid (get current-bid auction))
      (seller (get seller auction))
      (nft-contract (get nft-contract auction))
      (token-id (get token-id auction))
      (reserve (get reserve-price auction))
    )
      ;; Check if reserve was met
      (if (and (> final-bid u0) (>= final-bid reserve))
        ;; Successful auction - distribute funds
        (let (
          (winner (unwrap! (get highest-bidder auction) ERR-NOT-FOUND))
          (protocol-fee (/ (* final-bid PROTOCOL-FEE-BPS) u10000))
          (seller-proceeds (- final-bid protocol-fee))
        )
          ;; Pay seller
          (try! (as-contract (stx-transfer? seller-proceeds tx-sender seller)))
          
          ;; Pay protocol fee
          (try! (as-contract (stx-transfer? protocol-fee tx-sender (var-get fee-recipient))))
          
          ;; Update stats
          (var-set total-volume (+ (var-get total-volume) final-bid))
          
          ;; Mark as settled
          (map-set auctions auction-id (merge auction {
            is-active: false,
            is-settled: true
          }))
          
          ;; Clean up NFT mapping
          (map-delete nft-to-auction { nft-contract: nft-contract, token-id: token-id })
          
          ;; Increment settled count
          (var-set total-auctions-settled (+ (var-get total-auctions-settled) u1))
          
          (print {
            event: "auction-settled",
            auction-id: auction-id,
            winner: winner,
            final-price: final-bid,
            protocol-fee: protocol-fee,
            seller-proceeds: seller-proceeds
          })
          
          (ok true)
        )
        ;; Reserve not met or no bids - auction failed
        (begin
          ;; Refund highest bidder if any
          (match (get highest-bidder auction)
            bidder (try! (as-contract (stx-transfer? final-bid tx-sender bidder)))
            true
          )
          
          ;; Mark as settled/failed
          (map-set auctions auction-id (merge auction {
            is-active: false,
            is-settled: true
          }))
          
          ;; Clean up
          (map-delete nft-to-auction { nft-contract: nft-contract, token-id: token-id })
          
          (print {
            event: "auction-failed",
            auction-id: auction-id,
            reason: "reserve-not-met"
          })
          
          (ok true)
        )
      )
    )
  )
)

;; ============================================
;; PUBLIC FUNCTIONS - CANCELLATION
;; ============================================

;; Cancel auction (only if no bids)
(define-public (cancel-auction (auction-id uint))
  (let (
    (auction (unwrap! (map-get? auctions auction-id) ERR-NOT-FOUND))
  )
    ;; Only seller can cancel
    (asserts! (is-eq tx-sender (get seller auction)) ERR-NOT-SELLER)
    
    ;; Cannot cancel if there are bids
    (asserts! (is-eq (get current-bid auction) u0) ERR-HAS-BIDS)
    
    ;; Must be active
    (asserts! (get is-active auction) ERR-AUCTION-NOT-ACTIVE)
    
    ;; Mark as inactive
    (map-set auctions auction-id (merge auction {
      is-active: false
    }))
    
    ;; Clean up mapping
    (map-delete nft-to-auction { 
      nft-contract: (get nft-contract auction), 
      token-id: (get token-id auction) 
    })
    
    (print {
      event: "auction-cancelled",
      auction-id: auction-id,
      seller: tx-sender
    })
    
    (ok true)
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

;; Set fee recipient
(define-public (set-fee-recipient (recipient principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set fee-recipient recipient)
    (print { event: "fee-recipient-updated", recipient: recipient })
    (ok true)
  )
)

;; Set escrow contract
(define-public (set-escrow-contract (contract principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set escrow-contract contract)
    (print { event: "escrow-contract-updated", contract: contract })
    (ok true)
  )
)

;; Set royalty contract
(define-public (set-royalty-contract (contract principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set royalty-contract contract)
    (print { event: "royalty-contract-updated", contract: contract })
    (ok true)
  )
)

;; Set marketplace contract
(define-public (set-marketplace-contract (contract principal))
  (begin
    (asserts! (is-contract-owner) ERR-NOT-AUTHORIZED)
    (var-set marketplace-contract contract)
    (print { event: "marketplace-contract-updated", contract: contract })
    (ok true)
  )
)